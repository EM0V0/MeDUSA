import os, boto3, time
s3 = boto3.client("s3")

PPOSES = os.environ.get("S3_PREFIX_POSES","poses/")
PREPORT= os.environ.get("S3_PREFIX_REPORTS","reports/")

def _bucket() -> str:
    bucket = os.environ.get("S3_BUCKET")
    if not bucket:
        raise RuntimeError("S3_BUCKET env var must be set for storage access")
    return bucket

def make_file_key(scope: str, owner: str, filename: str) -> str:
    base = PPOSES if scope=="pose" else PREPORT
    ts = int(time.time())
    # Basic sanitize (Lambda behind WAF; clients still can pass unicode filenames)
    safe = filename.replace("/", "_")
    return f"{base}{owner}/{ts}_{safe}"

def presign_upload(key: str, content_type: str, ttl_sec:int=900):
    fields = {"Content-Type": content_type}
    conditions = [["eq","$Content-Type", content_type]]
    return s3.generate_presigned_post(
        Bucket=_bucket(), Key=key, Fields=fields, Conditions=conditions, ExpiresIn=ttl_sec
    )

def presign_download(key: str, ttl_sec:int=900):
    return s3.generate_presigned_url(
        "get_object", Params={"Bucket": _bucket(), "Key": key}, ExpiresIn=ttl_sec
    )
