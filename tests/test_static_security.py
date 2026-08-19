import base64
import hashlib
import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HTML = (ROOT / "drone_checker.html").read_text(encoding="utf-8")


class LawBaselineTests(unittest.TestCase):
    def test_app_uses_current_law_baseline(self):
        self.assertIn("const APP_LAW_DATE = '2026-07-14';", HTML)
        self.assertIn("const TARGET_FACILITY_BUFFER_METERS = 1000;", HTML)
        self.assertNotIn("改正案で1km拡大予定", HTML)
        self.assertNotIn("現行は施設周辺おおむね300m", HTML)

    def test_airport_warning_uses_shared_1000m_constant(self):
        self.assertIn("minMajor<=TARGET_FACILITY_BUFFER_METERS", HTML)
        self.assertIn("minDist <= TARGET_FACILITY_BUFFER_METERS", HTML)
        self.assertNotIn("minMajor<=300", HTML)
        self.assertNotIn("minDist <= 300", HTML)

    def test_law_status_matches_app(self):
        status = json.loads((ROOT / "law_status.json").read_text(encoding="utf-8"))
        self.assertEqual(status["app_version"], "6.3.1")
        self.assertEqual(status["latest_law_date"], "2026-07-14")
        self.assertEqual(status["app_law_date"], "2026-07-14")
        self.assertIn("npa.go.jp", status["npa_page_url"])

    def test_weekly_read_only_law_check_exists(self):
        workflow = (ROOT / ".github" / "workflows" / "law-review.yml").read_text(encoding="utf-8")
        self.assertIn("permissions:\n  contents: read", workflow)
        self.assertIn("age > 35", workflow)
        self.assertNotIn("contents: write", workflow)


class SupplyChainTests(unittest.TestCase):
    EXPECTED_VENDOR_SHA384 = {
        "vendor/leaflet/leaflet.css": "sHL9NAb7lN7rfvG5lfHpm643Xkcjzp4jFvuavGOndn6pjVqS6ny56CAt3nsEVT4H",
        "vendor/leaflet/leaflet.js": "cxOPjt7s7Iz04uaHJceBmS+qpjv2JkIHNVcuOrM+YHwZOmJGBXI00mdUXEq65HTH",
        "vendor/jszip/jszip.min.js": "+mbV2IY1Zk/X1p/nWllGySJSUN8uMs+gUAN10Or95UBH0fpj6GfKgPmgC5EXieXG",
    }

    def test_scripts_and_styles_are_local_and_pinned(self):
        self.assertNotIn("unpkg.com", HTML)
        for relative_path, expected in self.EXPECTED_VENDOR_SHA384.items():
            path = ROOT / relative_path
            self.assertTrue(path.is_file(), relative_path)
            actual = base64.b64encode(hashlib.sha384(path.read_bytes()).digest()).decode()
            self.assertEqual(actual, expected, relative_path)
            self.assertIn(relative_path, HTML)

    def test_csp_does_not_allow_third_party_scripts(self):
        csp = re.search(
            r'<meta http-equiv="Content-Security-Policy" content="([^"]+)">',
            HTML,
        )
        self.assertIsNotNone(csp)
        script_policy = next(
            part.strip() for part in csp.group(1).split(";")
            if part.strip().startswith("script-src")
        )
        self.assertEqual(script_policy, "script-src 'self' 'unsafe-inline'")

    def test_privacy_notice_matches_external_requests(self):
        for text in (
            "住所検索は入力した住所を国土地理院へ送信します。",
            "OpenStreetMapへ送信します。",
            "選択座標と予定日をOpen-Meteoへ送信します。",
            "個人情報を含めず、公開元からバージョン・法令確認日だけを取得します",
        ):
            self.assertIn(text, HTML)
        self.assertNotIn("外部送信なし", HTML)

    def test_startup_version_check_is_defined_and_uses_shared_status(self):
        self.assertIn("async function checkLatestVersion()", HTML)
        self.assertIn("function fetchRemoteStatus()", HTML)
        self.assertIn("const STATUS_URL = IS_LOCAL_APP ? GITHUB_RAW_BASE", HTML)
        self.assertIn("new URL('law_status.json',location.href).href", HTML)
        self.assertIn("fetch(STATUS_URL, {cache:'no-cache'})", HTML)
        self.assertIn("const status = await fetchRemoteStatus();", HTML)
        self.assertIn("if (IS_LOCAL_APP) try {", HTML)
        self.assertNotIn("const GITHUB_API_BASE", HTML)

    def test_geocoding_requires_explicit_candidate_selection(self):
        self.assertIn("showGeocodeCandidates(data.slice(0,5),addr);", HTML)
        self.assertIn("function normalizeGeocodeCandidate(item,fallback)", HTML)
        self.assertIn("button.addEventListener('click',()=>selectGeocodeCandidate(candidate));", HTML)
        self.assertNotIn("const name=data[0].properties?.title||addr", HTML)

    def test_vendor_licenses_are_bundled(self):
        for relative_path in (
            "vendor/leaflet/LICENSE",
            "vendor/jszip/LICENSE.markdown",
        ):
            self.assertTrue((ROOT / relative_path).is_file(), relative_path)

    def test_unused_xlsx_bundle_is_not_shipped(self):
        self.assertNotIn("xlsx.full.min.js", HTML)
        self.assertFalse((ROOT / "vendor" / "xlsx").exists())

    def test_backup_import_has_size_and_shape_limits(self):
        self.assertIn("MAX_BACKUP_FILE_BYTES = 2 * 1024 * 1024", HTML)
        self.assertIn("validateBackupData(data)", HTML)
        self.assertIn("data.flightLog.length > 5000", HTML)
        self.assertIn("data.history.length > 100", HTML)


class AwsStaticDeploymentTests(unittest.TestCase):
    def setUp(self):
        self.template = (
            ROOT / "deploy" / "aws" / "cloudformation" / "static-site.yaml"
        ).read_text(encoding="utf-8")
        self.build_script = (
            ROOT / "deploy" / "aws" / "scripts" / "01_配布フォルダ作成.ps1"
        ).read_text(encoding="utf-8")
        self.upload_script = (
            ROOT / "deploy" / "aws" / "scripts" / "02_S3へ配置.ps1"
        ).read_text(encoding="utf-8")

    def test_private_s3_is_retained_and_cloudfront_only(self):
        self.assertIn("DeletionPolicy: Retain", self.template)
        for setting in (
            "BlockPublicAcls: true",
            "BlockPublicPolicy: true",
            "IgnorePublicAcls: true",
            "RestrictPublicBuckets: true",
            "SigningBehavior: always",
            "SigningProtocol: sigv4",
            "Service: cloudfront.amazonaws.com",
        ):
            self.assertIn(setting, self.template)

    def test_cloudfront_enforces_https_and_security_headers(self):
        for setting in (
            "ViewerProtocolPolicy: redirect-to-https",
            "ResponseHeadersPolicyId: !Ref DroneSecurityHeaders",
            "FrameOption: DENY",
            "ReferrerPolicy: no-referrer",
            "StrictTransportSecurity:",
            "frame-ancestors 'none'",
        ):
            self.assertIn(setting, self.template)

    def test_phase1_does_not_add_always_on_compute(self):
        resource_types = re.findall(r"^\s+Type: (\S+)\s*$", self.template, re.MULTILINE)
        self.assertEqual(
            resource_types,
            [
                "AWS::S3::Bucket",
                "AWS::CloudFront::OriginAccessControl",
                "AWS::CloudFront::CachePolicy",
                "AWS::CloudFront::ResponseHeadersPolicy",
                "AWS::CloudFront::Distribution",
                "AWS::S3::BucketPolicy",
            ],
        )
        for resource in (
            "AWS::EC2::Instance",
            "AWS::Lambda::Function",
            "AWS::RDS::DBInstance",
            "AWS::ElasticLoadBalancingV2::LoadBalancer",
        ):
            self.assertNotIn(resource, self.template)

    def test_release_is_allowlisted_and_upload_never_deletes_remote_files(self):
        self.assertIn("$allowedFiles = @(", self.build_script)
        self.assertIn("release-manifest.json", self.build_script)
        self.assertIn("Type DEPLOY", self.upload_script)
        self.assertNotIn("--delete", self.upload_script)


if __name__ == "__main__":
    unittest.main()
