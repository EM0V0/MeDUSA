import os
import time
import secrets
from typing import Optional, Dict, Any, List, Tuple
from decimal import Decimal
import boto3
from boto3.dynamodb.conditions import Key, Attr

def _pose_pk(patient_id: str) -> str:
    return f"POSE#{patient_id}"

def _pose_sk(pose_id: str) -> str:
    return f"POSE#{pose_id}"

USE_MEMORY = os.environ.get("USE_MEMORY", "false").lower() == "true"
VERIFICATION_CODE_TTL = 600  # 10 minutes

# In-memory store for verification codes (development)
_verification_codes: Dict[str, Dict[str, Any]] = {}

if not USE_MEMORY:
    ddb = boto3.resource("dynamodb")

    def _table_with_schema(env_var: str):
        table = ddb.Table(os.environ[env_var])
        pk_attr = "id"
        sk_attr = None
        try:
            schema = table.key_schema
            if schema:
                pk_attr = schema[0]["AttributeName"]
            if len(schema) > 1:
                sk_attr = schema[1]["AttributeName"]
        except Exception:
            pass
        return table, pk_attr, sk_attr

    def _is_pk_sk(pk_attr: str, sk_attr: Optional[str]) -> bool:
        return pk_attr.lower() == "pk" and sk_attr is not None and sk_attr.lower() == "sk"

    T_USERS, USERS_PK_ATTR, USERS_SK_ATTR = _table_with_schema("DDB_TABLE_USERS")
    T_REFRESH, REFRESH_PK_ATTR, REFRESH_SK_ATTR = _table_with_schema("DDB_TABLE_REFRESH")
    T_POSES, POSES_PK_ATTR, POSES_SK_ATTR = _table_with_schema("DDB_TABLE_POSES")
    T_DEVICES, DEVICES_PK_ATTR, DEVICES_SK_ATTR = _table_with_schema("DDB_TABLE_DEVICES")
    T_PATIENT_PROFILES, PROFILES_PK_ATTR, PROFILES_SK_ATTR = _table_with_schema("DDB_TABLE_PATIENT_PROFILES")
    T_SESSIONS, SESSIONS_PK_ATTR, SESSIONS_SK_ATTR = _table_with_schema("DDB_TABLE_SESSIONS")
    T_TREMOR_ANALYSIS, TREMOR_PK_ATTR, TREMOR_SK_ATTR = _table_with_schema("DDB_TABLE_TREMOR_ANALYSIS")
    
    # New tables for additional features
    T_AUDIT_LOGS, AUDIT_PK_ATTR, AUDIT_SK_ATTR = _table_with_schema("DDB_TABLE_AUDIT_LOGS")
    T_SYSTEM_SETTINGS, SETTINGS_PK_ATTR, SETTINGS_SK_ATTR = _table_with_schema("DDB_TABLE_SYSTEM_SETTINGS")
    T_MESSAGES, MESSAGES_PK_ATTR, MESSAGES_SK_ATTR = _table_with_schema("DDB_TABLE_MESSAGES")
    T_SYMPTOMS, SYMPTOMS_PK_ATTR, SYMPTOMS_SK_ATTR = _table_with_schema("DDB_TABLE_SYMPTOMS")
    T_REPORTS, REPORTS_PK_ATTR, REPORTS_SK_ATTR = _table_with_schema("DDB_TABLE_REPORTS")

    USERS_SINGLE_TABLE = _is_pk_sk(USERS_PK_ATTR, USERS_SK_ATTR)
    REFRESH_SINGLE_TABLE = _is_pk_sk(REFRESH_PK_ATTR, REFRESH_SK_ATTR)
    POSES_SINGLE_TABLE = _is_pk_sk(POSES_PK_ATTR, POSES_SK_ATTR)
    DEVICES_SINGLE_TABLE = _is_pk_sk(DEVICES_PK_ATTR, DEVICES_SK_ATTR)
    PROFILES_SINGLE_TABLE = _is_pk_sk(PROFILES_PK_ATTR, PROFILES_SK_ATTR)
    SESSIONS_SINGLE_TABLE = _is_pk_sk(SESSIONS_PK_ATTR, SESSIONS_SK_ATTR)
    TREMOR_SINGLE_TABLE = _is_pk_sk(TREMOR_PK_ATTR, TREMOR_SK_ATTR)

    def _user_key(user_id: str) -> Dict[str, str]:
        if USERS_SINGLE_TABLE:
            return {
                USERS_PK_ATTR: f"USER#{user_id}",
                USERS_SK_ATTR: "PROFILE",
            }
        return {USERS_PK_ATTR: user_id}

    def _refresh_key(token: str) -> Dict[str, str]:
        if REFRESH_SINGLE_TABLE:
            key = {REFRESH_PK_ATTR: f"REFRESH#{token}"}
            if REFRESH_SK_ATTR:
                key[REFRESH_SK_ATTR] = "SESSION"
            return key
        return {REFRESH_PK_ATTR: token}

else:
    _users: Dict[str, Dict[str,Any]] = {}
    _refresh: Dict[str, Dict[str,Any]] = {}
    _poses: List[Dict[str,Any]] = []
    _devices: List[Dict[str,Any]] = []
    _patient_profiles: Dict[str, Dict[str,Any]] = {}
    _sessions: Dict[str, Dict[str,Any]] = {}
    _tremor_analysis: List[Dict[str,Any]] = []
    _audit_logs: List[Dict[str,Any]] = []
    _system_settings: Dict[str, Dict[str,Any]] = {}
    _messages: List[Dict[str,Any]] = []
    _symptoms: List[Dict[str,Any]] = []
    _reports: List[Dict[str,Any]] = []
    USERS_SINGLE_TABLE = False
    REFRESH_SINGLE_TABLE = False
    POSES_SINGLE_TABLE = False
    DEVICES_SINGLE_TABLE = False
    PROFILES_SINGLE_TABLE = False
    SESSIONS_SINGLE_TABLE = False
    TREMOR_SINGLE_TABLE = False
    USERS_PK_ATTR, USERS_SK_ATTR = "id", None
    REFRESH_PK_ATTR, REFRESH_SK_ATTR = "token", None
    POSES_PK_ATTR, POSES_SK_ATTR = "patientId", None
    TREMOR_PK_ATTR, TREMOR_SK_ATTR = "patient_id", "timestamp"
    AUDIT_PK_ATTR, AUDIT_SK_ATTR = "pk", "sk"
    SETTINGS_PK_ATTR, SETTINGS_SK_ATTR = "settingKey", None
    MESSAGES_PK_ATTR, MESSAGES_SK_ATTR = "conversationId", "messageId"
    SYMPTOMS_PK_ATTR, SYMPTOMS_SK_ATTR = "patientId", "recordId"
    REPORTS_PK_ATTR, REPORTS_SK_ATTR = "reportId", None

    def _user_key(user_id: str) -> Dict[str,str]:
        return {"id": user_id}

    def _refresh_key(token: str) -> Dict[str,str]:
        return {"token": token}

def put_user(u: Dict[str,Any]):
    if USE_MEMORY:
        _users[u["id"]] = u
        return
    item = dict(u)
    if USERS_SINGLE_TABLE:
        item.update(_user_key(u["id"]))
    T_USERS.put_item(Item=item)

def get_user_by_email(email: str) -> Optional[Dict[str,Any]]:
    if USE_MEMORY:
        return next((u for u in _users.values() if u["email"]==email), None)
    resp = T_USERS.query(IndexName="email-index",
                         KeyConditionExpression=Key("email").eq(email),
                         Limit=1)
    items = resp.get("Items", [])
    return items[0] if items else None

def get_user(user_id: str) -> Optional[Dict[str,Any]]:
    if USE_MEMORY:
        return _users.get(user_id)
    resp = T_USERS.get_item(Key=_user_key(user_id))
    return resp.get("Item")

def delete_user(user_id: str) -> bool:
    """Hard-delete a user record from DynamoDB."""
    if USE_MEMORY:
        return _users.pop(user_id, None) is not None
    try:
        T_USERS.delete_item(Key=_user_key(user_id))
        return True
    except Exception:
        return False

def list_users(role: Optional[str] = None, limit: int = 50, next_token: Optional[str] = None) -> Tuple[List[Dict[str,Any]], Optional[str]]:
    """
    List users with optional role filter.
    Returns (users_list, next_token)
    """
    if USE_MEMORY:
        users = list(_users.values())
        if role:
            users = [u for u in users if u.get("role") == role]
        # Simple pagination for in-memory
        start_idx = 0
        if next_token:
            for i, u in enumerate(users):
                if u["id"] == next_token:
                    start_idx = i + 1
                    break
        end_idx = start_idx + limit
        result = users[start_idx:end_idx]
        new_token = result[-1]["id"] if len(result) == limit and end_idx < len(users) else None
        return result, new_token
    
    # DynamoDB scan with optional filter
    scan_kwargs = {"Limit": limit}
    
    if role:
        scan_kwargs["FilterExpression"] = Attr("role").eq(role)
    
    if next_token:
        scan_kwargs["ExclusiveStartKey"] = _user_key(next_token)
    
    resp = T_USERS.scan(**scan_kwargs)
    items = resp.get("Items", [])
    
    # Get next token from LastEvaluatedKey
    last_key = resp.get("LastEvaluatedKey")
    new_next_token = None
    if last_key:
        # Extract the user id from the key
        if USERS_SINGLE_TABLE:
            pk_value = last_key.get(USERS_PK_ATTR, "")
            new_next_token = pk_value.replace("USER#", "") if pk_value.startswith("USER#") else pk_value
        else:
            new_next_token = last_key.get(USERS_PK_ATTR)
    
    return items, new_next_token

def update_user(user_id: str, updates: Dict[str,Any]) -> bool:
    """
    Update user attributes. Supports partial updates.
    Handles None values by removing attributes.
    """
    if USE_MEMORY:
        if user_id in _users:
            for k, v in updates.items():
                if v is None:
                    _users[user_id].pop(k, None)
                else:
                    _users[user_id][k] = v
            return True
        return False
    
    # Build update expression for DynamoDB
    update_parts = []
    remove_parts = []
    expr_attr_names = {}
    expr_attr_values = {}
    
    for i, (key, value) in enumerate(updates.items()):
        attr_name = f"#attr{i}"
        expr_attr_names[attr_name] = key
        
        if value is None:
            remove_parts.append(attr_name)
        else:
            attr_value = f":val{i}"
            update_parts.append(f"{attr_name} = {attr_value}")
            expr_attr_values[attr_value] = value
    
    update_expression = ""
    if update_parts:
        update_expression += "SET " + ", ".join(update_parts)
    if remove_parts:
        if update_expression:
            update_expression += " "
        update_expression += "REMOVE " + ", ".join(remove_parts)
    
    if not update_expression:
        return True
    
    try:
        update_kwargs = {
            "Key": _user_key(user_id),
            "UpdateExpression": update_expression,
            "ExpressionAttributeNames": expr_attr_names
        }
        if expr_attr_values:
            update_kwargs["ExpressionAttributeValues"] = expr_attr_values
            
        T_USERS.update_item(**update_kwargs)
        return True
    except Exception as e:
        print(f"[db] Error updating user {user_id}: {e}")
        return False

def save_refresh(token: str, sess: Dict[str,Any]):
    if USE_MEMORY:
        _refresh[token] = sess
        return
    item = {"token": token, **sess}
    if REFRESH_SINGLE_TABLE:
        item.update(_refresh_key(token))
    T_REFRESH.put_item(Item=item)

def take_refresh(token: str) -> Optional[Dict[str,Any]]:
    if USE_MEMORY:
        return _refresh.pop(token, None)
    key = _refresh_key(token)
    resp = T_REFRESH.get_item(Key=key)


# ========== Verification Code Functions ==========

def generate_verification_code() -> str:
    """Generate a 6-digit verification code"""
    return ''.join([str(secrets.randbelow(10)) for _ in range(6)])

def save_verification_code(email: str, code: str, code_type: str = "registration") -> bool:
    """
    Save verification code with TTL.
    Uses the nonces table for storage with automatic expiration.
    """
    if USE_MEMORY:
        _verification_codes[email] = {
            "code": code,
            "type": code_type,
            "created_at": int(time.time()),
            "expires_at": int(time.time()) + VERIFICATION_CODE_TTL
        }
        return True
    
    try:
        nonces_table = ddb.Table(os.environ.get("DDB_TABLE_NONCES", "medusa-nonces-prod"))
        nonces_table.put_item(Item={
            "nonce": f"VERIFY#{email}#{code_type}",  # Unique key per email+type
            "code": code,
            "email": email,
            "type": code_type,
            "created_at": int(time.time()),
            "ttl": int(time.time()) + VERIFICATION_CODE_TTL  # Auto-delete after 10 min
        })
        return True
    except Exception as e:
        print(f"[db] Error saving verification code: {e}")
        return False

def verify_and_consume_code(email: str, code: str, code_type: str = "registration") -> bool:
    """
    Verify a code and consume it (delete after verification).
    Returns True if code is valid and not expired.
    """
    if USE_MEMORY:
        stored = _verification_codes.get(email)
        if not stored:
            return False
        if stored["type"] != code_type:
            return False
        if stored["expires_at"] < int(time.time()):
            del _verification_codes[email]
            return False
        if stored["code"] != code:
            return False
        # Code is valid - consume it
        del _verification_codes[email]
        return True
    
    try:
        nonces_table = ddb.Table(os.environ.get("DDB_TABLE_NONCES", "medusa-nonces-prod"))
        key = {"nonce": f"VERIFY#{email}#{code_type}"}
        
        # Get the stored code
        resp = nonces_table.get_item(Key=key)
        item = resp.get("Item")
        
        if not item:
            print(f"[db] No verification code found for {email}")
            return False
        
        # Check if expired (extra safety, TTL should handle this)
        if item.get("ttl", 0) < int(time.time()):
            nonces_table.delete_item(Key=key)
            print(f"[db] Verification code expired for {email}")
            return False
        
        # Check code match
        if item.get("code") != code:
            print(f"[db] Verification code mismatch for {email}")
            return False
        
        # Code is valid - consume it (delete)
        nonces_table.delete_item(Key=key)
        print(f"[db] Verification code consumed for {email}")
        return True
        
    except Exception as e:
        print(f"[db] Error verifying code: {e}")
        return False

def has_pending_verification(email: str, code_type: str = "registration", min_age_seconds: int = 60) -> bool:
    """
    Check if there's a pending verification code for this email.
    
    Args:
        email: Email address
        code_type: Type of verification code
        min_age_seconds: Minimum age of existing code before allowing new request (rate limiting)
    
    Returns:
        True if there's a valid pending code that's less than min_age_seconds old
    """
    if USE_MEMORY:
        stored = _verification_codes.get(email)
        if not stored or stored["type"] != code_type:
            return False
        # Check if code exists and is not expired
        if stored["expires_at"] <= int(time.time()):
            return False  # Expired, can request new one
        # Check rate limiting: only block if code is very recent (less than min_age_seconds old)
        code_age = int(time.time()) - stored["created_at"]
        return code_age < min_age_seconds
    
    try:
        nonces_table = ddb.Table(os.environ.get("DDB_TABLE_NONCES", "medusa-nonces-prod"))
        key = {"nonce": f"VERIFY#{email}#{code_type}"}
        resp = nonces_table.get_item(Key=key)
        item = resp.get("Item")
        if not item:
            return False  # No code, can request
        # Check if expired
        if item.get("ttl", 0) <= int(time.time()):
            return False  # Expired, can request new one
        # Check rate limiting: only block if code is very recent
        code_age = int(time.time()) - item.get("created_at", 0)
        return code_age < min_age_seconds
    except Exception:
        return False
        T_REFRESH.delete_item(Key=key)
    return item

def list_poses_by_patient(pid: str, limit:int=50, next_token=None) -> Tuple[List[Dict[str,Any]], Any]:
    if USE_MEMORY:
        items = [p for p in _poses if p["patientId"]==pid]
        return items[:limit], None
    if POSES_SINGLE_TABLE:
        key_expr = Key(POSES_PK_ATTR).eq(_pose_pk(pid))
        kw = {
            "KeyConditionExpression": key_expr,
            "Limit": limit
        }
    else:
        # Direct query using patientId as HASH key (no GSI needed)
        kw = {"KeyConditionExpression":Key("patientId").eq(pid),
              "Limit":limit}
    if next_token: kw["ExclusiveStartKey"] = next_token
    resp = T_POSES.query(**kw)
    return resp.get("Items", []), resp.get("LastEvaluatedKey")

def create_pose(p: Dict[str,Any]):
    if USE_MEMORY:
        _poses.append(p)
        return
    item = dict(p)
    if POSES_SINGLE_TABLE:
        item[POSES_PK_ATTR] = _pose_pk(p["patientId"])
        if POSES_SK_ATTR:
            item[POSES_SK_ATTR] = _pose_sk(p["id"])
    T_POSES.put_item(Item=item)

# ========================================
# Device Operations
# ========================================

def create_device(device: Dict[str, Any]) -> None:
    """Create a new device"""
    if USE_MEMORY:
        _devices.append(device)
        return
    T_DEVICES.put_item(Item=device)

def get_device(device_id: str) -> Optional[Dict[str, Any]]:
    """Get device by ID"""
    if USE_MEMORY:
        for d in _devices:
            if d["id"] == device_id:
                return d
        return None
    resp = T_DEVICES.get_item(Key={"id": device_id})
    return resp.get("Item")

def get_device_by_mac(mac_address: str) -> Optional[Dict[str, Any]]:
    """Get device by MAC address"""
    if USE_MEMORY:
        for d in _devices:
            if d["macAddress"] == mac_address:
                return d
        return None
    resp = T_DEVICES.query(
        IndexName="macAddress-index",
        KeyConditionExpression=Key("macAddress").eq(mac_address),
        Limit=1
    )
    items = resp.get("Items", [])
    return items[0] if items else None

def get_devices_by_patient(patient_id: str) -> List[Dict[str, Any]]:
    """Get all devices for a patient (personal devices only)"""
    if USE_MEMORY:
        return [d for d in _devices if d.get("patientId") == patient_id]
    # No index for patientId anymore (devices are in shared pool)
    # Use scan with filter for personal devices
    resp = T_DEVICES.scan(
        FilterExpression=Attr("patientId").eq(patient_id)
    )
    return resp.get("Items", [])

def get_all_devices() -> List[Dict[str, Any]]:
    """Get all devices (admin only)"""
    if USE_MEMORY:
        return _devices
    resp = T_DEVICES.scan()
    return resp.get("Items", [])

def update_device(device_id: str, updates: Dict[str, Any]) -> None:
    """Update device fields"""
    if USE_MEMORY:
        for d in _devices:
            if d["id"] == device_id:
                d.update(updates)
                return
        return
    
    # Build update expression
    update_expr = "SET "
    expr_attr_values = {}
    expr_attr_names = {}
    
    for i, (key, value) in enumerate(updates.items()):
        if i > 0:
            update_expr += ", "
        attr_name = f"#attr{i}"
        attr_value = f":val{i}"
        update_expr += f"{attr_name} = {attr_value}"
        expr_attr_names[attr_name] = key
        expr_attr_values[attr_value] = value
    
    T_DEVICES.update_item(
        Key={"id": device_id},
        UpdateExpression=update_expr,
        ExpressionAttributeNames=expr_attr_names,
        ExpressionAttributeValues=expr_attr_values
    )

def delete_device(device_id: str) -> None:
    """Delete a device"""
    if USE_MEMORY:
        global _devices
        _devices = [d for d in _devices if d["id"] != device_id]
        return
    T_DEVICES.delete_item(Key={"id": device_id})

# ========================================
# Patient Profile Operations
# ========================================

def create_patient_profile(profile: Dict[str, Any]) -> None:
    """Create a patient profile"""
    if USE_MEMORY:
        _patient_profiles[profile["userId"]] = profile
        return
    T_PATIENT_PROFILES.put_item(Item=profile)

def get_patient_profile(user_id: str) -> Optional[Dict[str, Any]]:
    """Get patient profile by user ID"""
    if USE_MEMORY:
        return _patient_profiles.get(user_id)
    resp = T_PATIENT_PROFILES.get_item(Key={"userId": user_id})
    return resp.get("Item")

def get_patients_by_doctor(doctor_id: str) -> List[Dict[str, Any]]:
    """Get all patients assigned to a doctor"""
    if USE_MEMORY:
        return [p for p in _patient_profiles.values() if p.get("doctorId") == doctor_id]
    
    try:
        resp = T_PATIENT_PROFILES.query(
            IndexName="doctorId-index",
            KeyConditionExpression=Key("doctorId").eq(doctor_id)
        )
        return resp.get("Items", [])
    except Exception as e:
        print(f"Error querying patients by doctor: {e}")
        return []

def get_all_patient_profiles() -> List[Dict[str, Any]]:
    """Get all patient profiles (admin only)"""
    if USE_MEMORY:
        return list(_patient_profiles.values())
    resp = T_PATIENT_PROFILES.scan()
    return resp.get("Items", [])

def update_patient_profile(user_id: str, updates: Dict[str, Any]) -> None:
    """Update patient profile fields"""
    if USE_MEMORY:
        if user_id in _patient_profiles:
            _patient_profiles[user_id].update(updates)
        return
    
    # Build update expression
    update_expr = "SET "
    expr_attr_values = {}
    expr_attr_names = {}
    
    for i, (key, value) in enumerate(updates.items()):
        if i > 0:
            update_expr += ", "
        attr_name = f"#attr{i}"
        attr_value = f":val{i}"
        update_expr += f"{attr_name} = {attr_value}"
        expr_attr_names[attr_name] = key
        expr_attr_values[attr_value] = value
    
    T_PATIENT_PROFILES.update_item(
        Key={"userId": user_id},
        UpdateExpression=update_expr,
        ExpressionAttributeNames=expr_attr_names,
        ExpressionAttributeValues=expr_attr_values
    )

def delete_patient_profile(user_id: str) -> None:
    """Delete a patient profile"""
    if USE_MEMORY:
        if user_id in _patient_profiles:
            del _patient_profiles[user_id]
        return
    T_PATIENT_PROFILES.delete_item(Key={"userId": user_id})

# ========================================
# Session Operations (Device-Patient Dynamic Binding)
# ========================================

def create_session(session: Dict[str, Any]) -> None:
    """Create a measurement session"""
    if USE_MEMORY:
        _sessions[session["sessionId"]] = session
        return
    T_SESSIONS.put_item(Item=session)

def get_session(session_id: str) -> Optional[Dict[str, Any]]:
    """Get session by ID"""
    if USE_MEMORY:
        return _sessions.get(session_id)
    resp = T_SESSIONS.get_item(Key={SESSIONS_PK_ATTR: session_id})
    return resp.get("Item")

def get_session_by_id(session_id: str) -> Optional[Dict[str,Any]]:
    if USE_MEMORY:
        return _sessions.get(session_id)
    resp = T_SESSIONS.get_item(Key={SESSIONS_PK_ATTR: session_id})
    return resp.get("Item")

from datetime import datetime, timezone

def get_tremor_analysis(patient_id: str, start_time: Optional[int] = None, end_time: Optional[int] = None, limit: int = 100) -> Tuple[List[Dict[str,Any]], int]:
    """
    Query tremor analysis data for a patient.
    Returns (items, count)
    """
    if USE_MEMORY:
        # Simple memory implementation
        items = [t for t in _tremor_analysis if t.get("patient_id") == patient_id]
        if start_time:
            items = [t for t in items if t.get("timestamp", 0) >= start_time]
        if end_time:
            items = [t for t in items if t.get("timestamp", 0) <= end_time]
        items.sort(key=lambda x: x.get("timestamp", 0), reverse=True)
        return items[:limit], len(items)

    key_condition = Key(TREMOR_PK_ATTR).eq(patient_id)
    
    # Convert int timestamps to ISO strings for DynamoDB query if needed
    # The DB stores timestamps as ISO strings (e.g. "2025-11-15T22:17:06.160809Z")
    if start_time:
        start_iso = datetime.fromtimestamp(start_time, timezone.utc).isoformat().replace("+00:00", "Z")
    if end_time:
        end_iso = datetime.fromtimestamp(end_time, timezone.utc).isoformat().replace("+00:00", "Z")

    if start_time and end_time:
        key_condition = key_condition & Key(TREMOR_SK_ATTR).between(start_iso, end_iso)
    elif start_time:
        key_condition = key_condition & Key(TREMOR_SK_ATTR).gte(start_iso)
    
    # We want latest first, so ScanIndexForward=False
    try:
        resp = T_TREMOR_ANALYSIS.query(
            KeyConditionExpression=key_condition,
            ScanIndexForward=False,
            Limit=limit
        )
        items = resp.get("Items", [])
        count = resp.get("Count", 0)
        
        # Post-processing
        for item in items:
            # Convert Decimals to float/int
            for k, v in item.items():
                if isinstance(v, Decimal):
                    if v % 1 == 0:
                        item[k] = int(v)
                    else:
                        item[k] = float(v)
            
            # Convert timestamp string back to int for API response model
            if "timestamp" in item and isinstance(item["timestamp"], str):
                try:
                    # Parse ISO string to timestamp
                    dt = datetime.fromisoformat(item["timestamp"].replace("Z", "+00:00"))
                    item["timestamp"] = int(dt.timestamp())
                except Exception:
                    pass # Keep as is if parsing fails
                        
        return items, count
    except Exception as e:
        print(f"Error querying tremor analysis: {e}")
        return [], 0


# ============== Audit Logs ==============

def put_audit_log(log: Dict[str, Any]) -> bool:
    """Store an audit log entry"""
    if USE_MEMORY:
        _audit_logs.insert(0, log)
        # Keep only last 10000 logs in memory
        if len(_audit_logs) > 10000:
            _audit_logs.pop()
        return True
    
    try:
        T_AUDIT_LOGS.put_item(Item=log)
        return True
    except Exception as e:
        print(f"Error storing audit log: {e}")
        return False


def get_audit_logs(
    event_type: Optional[str] = None,
    user_id: Optional[str] = None,
    severity: Optional[str] = None,
    start_time: Optional[str] = None,
    end_time: Optional[str] = None,
    limit: int = 100,
    next_token: Optional[str] = None
) -> Tuple[List[Dict[str, Any]], Optional[str]]:
    """Query audit logs with optional filters"""
    if USE_MEMORY:
        items = _audit_logs.copy()
        if event_type:
            items = [i for i in items if i.get("eventType") == event_type]
        if user_id:
            items = [i for i in items if i.get("userId") == user_id]
        if severity:
            items = [i for i in items if i.get("severity") == severity]
        if start_time:
            items = [i for i in items if i.get("sk", "") >= start_time]
        if end_time:
            items = [i for i in items if i.get("sk", "") <= end_time]
        return items[:limit], None
    
    try:
        # Use GSI based on filter
        if event_type:
            key_condition = Key("eventType").eq(event_type)
            if start_time and end_time:
                key_condition = key_condition & Key("sk").between(start_time, end_time)
            elif start_time:
                key_condition = key_condition & Key("sk").gte(start_time)
            
            params = {
                "IndexName": "eventType-index",
                "KeyConditionExpression": key_condition,
                "ScanIndexForward": False,
                "Limit": limit
            }
        elif user_id:
            key_condition = Key("userId").eq(user_id)
            if start_time and end_time:
                key_condition = key_condition & Key("sk").between(start_time, end_time)
            elif start_time:
                key_condition = key_condition & Key("sk").gte(start_time)
            
            params = {
                "IndexName": "userId-index",
                "KeyConditionExpression": key_condition,
                "ScanIndexForward": False,
                "Limit": limit
            }
        else:
            # Scan all logs (use partition key ALL for all logs)
            key_condition = Key("pk").eq("AUDIT#ALL")
            if start_time and end_time:
                key_condition = key_condition & Key("sk").between(start_time, end_time)
            elif start_time:
                key_condition = key_condition & Key("sk").gte(start_time)
            
            params = {
                "KeyConditionExpression": key_condition,
                "ScanIndexForward": False,
                "Limit": limit
            }
        
        if next_token:
            import json
            import base64
            params["ExclusiveStartKey"] = json.loads(base64.b64decode(next_token).decode())
        
        # Add severity filter if specified
        if severity:
            params["FilterExpression"] = Attr("severity").eq(severity)
        
        resp = T_AUDIT_LOGS.query(**params)
        items = resp.get("Items", [])
        
        # Convert Decimals
        for item in items:
            for k, v in item.items():
                if isinstance(v, Decimal):
                    item[k] = int(v) if v % 1 == 0 else float(v)
        
        # Encode next token
        last_key = resp.get("LastEvaluatedKey")
        token = None
        if last_key:
            import json
            import base64
            token = base64.b64encode(json.dumps(last_key).encode()).decode()
        
        return items, token
    except Exception as e:
        print(f"Error querying audit logs: {e}")
        return [], None


# ============== System Settings ==============

def get_system_setting(key: str) -> Optional[Dict[str, Any]]:
    """Get a system setting by key"""
    if USE_MEMORY:
        return _system_settings.get(key)
    
    try:
        resp = T_SYSTEM_SETTINGS.get_item(Key={"settingKey": key})
        return resp.get("Item")
    except Exception as e:
        print(f"Error getting system setting: {e}")
        return None


def get_all_system_settings() -> Dict[str, Any]:
    """Get all system settings"""
    if USE_MEMORY:
        return {k: v.get("value") for k, v in _system_settings.items()}
    
    try:
        resp = T_SYSTEM_SETTINGS.scan()
        items = resp.get("Items", [])
        return {item["settingKey"]: item.get("value") for item in items}
    except Exception as e:
        print(f"Error getting all system settings: {e}")
        return {}


def put_system_setting(key: str, value: Any, updated_by: str) -> bool:
    """Update a system setting"""
    if USE_MEMORY:
        _system_settings[key] = {
            "settingKey": key,
            "value": value,
            "updatedAt": datetime.now(timezone.utc).isoformat(),
            "updatedBy": updated_by
        }
        return True
    
    try:
        T_SYSTEM_SETTINGS.put_item(Item={
            "settingKey": key,
            "value": value,
            "updatedAt": datetime.now(timezone.utc).isoformat(),
            "updatedBy": updated_by
        })
        return True
    except Exception as e:
        print(f"Error updating system setting: {e}")
        return False


# ============== Messages ==============

def create_conversation(conversation_id: str, participants: List[str], created_by: str) -> Dict[str, Any]:
    """Create a new conversation"""
    conversation = {
        "conversationId": conversation_id,
        "participants": participants,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "createdBy": created_by,
        "lastMessageAt": datetime.now(timezone.utc).isoformat(),
        "lastMessagePreview": ""
    }
    
    if USE_MEMORY:
        # Store in memory (simplified)
        return conversation
    
    # For DynamoDB, we store conversation metadata with messageId = "METADATA"
    try:
        T_MESSAGES.put_item(Item={
            **conversation,
            "messageId": "METADATA",
            "participantId": participants[0]  # Primary participant for indexing
        })
        # Also create index entries for other participants
        for pid in participants[1:]:
            T_MESSAGES.put_item(Item={
                **conversation,
                "messageId": "METADATA",
                "participantId": pid
            })
        return conversation
    except Exception as e:
        print(f"Error creating conversation: {e}")
        return conversation


def get_conversations(user_id: str, limit: int = 50) -> List[Dict[str, Any]]:
    """Get conversations for a user"""
    if USE_MEMORY:
        return [m for m in _messages if user_id in m.get("participants", [])][:limit]
    
    try:
        resp = T_MESSAGES.query(
            IndexName="participantId-index",
            KeyConditionExpression=Key("participantId").eq(user_id) & Key("messageId").eq("METADATA"),
            Limit=limit
        )
        return resp.get("Items", [])
    except Exception as e:
        print(f"Error getting conversations: {e}")
        return []


def send_message(conversation_id: str, sender_id: str, content: str, message_type: str = "text") -> Dict[str, Any]:
    """Send a message in a conversation"""
    message_id = f"MSG#{datetime.now(timezone.utc).isoformat()}#{secrets.token_hex(4)}"
    message = {
        "conversationId": conversation_id,
        "messageId": message_id,
        "senderId": sender_id,
        "content": content,
        "messageType": message_type,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "readBy": [sender_id]
    }
    
    if USE_MEMORY:
        _messages.append(message)
        return message
    
    try:
        T_MESSAGES.put_item(Item={
            **message,
            "participantId": sender_id  # For indexing
        })
        return message
    except Exception as e:
        print(f"Error sending message: {e}")
        return message


def get_messages(conversation_id: str, limit: int = 50, before: Optional[str] = None) -> List[Dict[str, Any]]:
    """Get messages in a conversation"""
    if USE_MEMORY:
        msgs = [m for m in _messages if m.get("conversationId") == conversation_id]
        msgs.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
        return msgs[:limit]
    
    try:
        key_condition = Key("conversationId").eq(conversation_id) & Key("messageId").begins_with("MSG#")
        params = {
            "KeyConditionExpression": key_condition,
            "ScanIndexForward": False,
            "Limit": limit
        }
        if before:
            params["ExclusiveStartKey"] = {"conversationId": conversation_id, "messageId": before}
        
        resp = T_MESSAGES.query(**params)
        return resp.get("Items", [])
    except Exception as e:
        print(f"Error getting messages: {e}")
        return []


# ============== Symptoms ==============

def create_symptom_record(patient_id: str, record: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new symptom record"""
    record_id = f"SYM#{datetime.now(timezone.utc).isoformat()}#{secrets.token_hex(4)}"
    symptom = {
        "patientId": patient_id,
        "recordId": record_id,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        **record
    }
    
    if USE_MEMORY:
        _symptoms.append(symptom)
        return symptom
    
    try:
        T_SYMPTOMS.put_item(Item=symptom)
        return symptom
    except Exception as e:
        print(f"Error creating symptom record: {e}")
        return symptom


def get_symptom_records(patient_id: str, limit: int = 50) -> List[Dict[str, Any]]:
    """Get symptom records for a patient"""
    if USE_MEMORY:
        items = [s for s in _symptoms if s.get("patientId") == patient_id]
        items.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
        return items[:limit]
    
    try:
        resp = T_SYMPTOMS.query(
            KeyConditionExpression=Key("patientId").eq(patient_id),
            ScanIndexForward=False,
            Limit=limit
        )
        return resp.get("Items", [])
    except Exception as e:
        print(f"Error getting symptom records: {e}")
        return []


def delete_symptom_record(patient_id: str, record_id: str) -> bool:
    """Delete a symptom record"""
    if USE_MEMORY:
        global _symptoms
        _symptoms = [s for s in _symptoms if not (s.get("patientId") == patient_id and s.get("recordId") == record_id)]
        return True
    
    try:
        T_SYMPTOMS.delete_item(Key={"patientId": patient_id, "recordId": record_id})
        return True
    except Exception as e:
        print(f"Error deleting symptom record: {e}")
        return False


# ============== Reports ==============

def create_report(report: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new report"""
    report_id = f"RPT-{secrets.token_hex(6).upper()}"
    report_data = {
        "reportId": report_id,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "status": "pending",
        **report
    }
    
    if USE_MEMORY:
        _reports.append(report_data)
        return report_data
    
    try:
        T_REPORTS.put_item(Item=report_data)
        return report_data
    except Exception as e:
        print(f"Error creating report: {e}")
        return report_data


def get_reports(
    patient_id: Optional[str] = None,
    author_id: Optional[str] = None,
    limit: int = 50
) -> List[Dict[str, Any]]:
    """Get reports with optional filters"""
    if USE_MEMORY:
        items = _reports.copy()
        if patient_id:
            items = [r for r in items if r.get("patientId") == patient_id]
        if author_id:
            items = [r for r in items if r.get("authorId") == author_id]
        items.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
        return items[:limit]
    
    try:
        if patient_id:
            resp = T_REPORTS.query(
                IndexName="patientId-index",
                KeyConditionExpression=Key("patientId").eq(patient_id),
                ScanIndexForward=False,
                Limit=limit
            )
        elif author_id:
            resp = T_REPORTS.query(
                IndexName="authorId-index",
                KeyConditionExpression=Key("authorId").eq(author_id),
                ScanIndexForward=False,
                Limit=limit
            )
        else:
            resp = T_REPORTS.scan(Limit=limit)
        
        return resp.get("Items", [])
    except Exception as e:
        print(f"Error getting reports: {e}")
        return []


def get_report(report_id: str) -> Optional[Dict[str, Any]]:
    """Get a single report by ID"""
    if USE_MEMORY:
        for r in _reports:
            if r.get("reportId") == report_id:
                return r
        return None
    
    try:
        resp = T_REPORTS.get_item(Key={"reportId": report_id})
        return resp.get("Item")
    except Exception as e:
        print(f"Error getting report: {e}")
        return None


def update_report(report_id: str, updates: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Update a report"""
    if USE_MEMORY:
        for i, r in enumerate(_reports):
            if r.get("reportId") == report_id:
                _reports[i].update(updates)
                _reports[i]["updatedAt"] = datetime.now(timezone.utc).isoformat()
                return _reports[i]
        return None
    
    try:
        update_expr = "SET " + ", ".join(f"#{k} = :{k}" for k in updates.keys())
        update_expr += ", #updatedAt = :updatedAt"
        
        expr_names = {f"#{k}": k for k in updates.keys()}
        expr_names["#updatedAt"] = "updatedAt"
        
        expr_values = {f":{k}": v for k, v in updates.items()}
        expr_values[":updatedAt"] = datetime.now(timezone.utc).isoformat()
        
        resp = T_REPORTS.update_item(
            Key={"reportId": report_id},
            UpdateExpression=update_expr,
            ExpressionAttributeNames=expr_names,
            ExpressionAttributeValues=expr_values,
            ReturnValues="ALL_NEW"
        )
        return resp.get("Attributes")
    except Exception as e:
        print(f"Error updating report: {e}")
        return None


def delete_report(report_id: str) -> bool:
    """Delete a report"""
    if USE_MEMORY:
        global _reports
        _reports = [r for r in _reports if r.get("reportId") != report_id]
        return True
    
    try:
        T_REPORTS.delete_item(Key={"reportId": report_id})
        return True
    except Exception as e:
        print(f"Error deleting report: {e}")
        return False


# ============== Admin Dashboard Stats ==============

def get_dashboard_stats() -> Dict[str, Any]:
    """Get dashboard statistics for admin"""
    if USE_MEMORY:
        return {
            "totalUsers": len(_users),
            "totalDoctors": len([u for u in _users.values() if u.get("role") == "doctor"]),
            "totalPatients": len([u for u in _users.values() if u.get("role") == "patient"]),
            "totalDevices": len(_devices),
            "activeDevices": len([d for d in _devices if d.get("status") == "active"]),
            "activeSessions": len([s for s in _sessions.values() if s.get("status") == "active"]),
            "totalReports": len(_reports),
            "recentAuditLogs": len(_audit_logs)
        }
    
    try:
        # Count users by role
        users_resp = T_USERS.scan(Select="COUNT")
        total_users = users_resp.get("Count", 0)
        
        # Count devices
        devices_resp = T_DEVICES.scan(Select="COUNT")
        total_devices = devices_resp.get("Count", 0)
        
        # Count active sessions
        sessions_resp = T_SESSIONS.query(
            IndexName="status-index",
            KeyConditionExpression=Key("status").eq("active"),
            Select="COUNT"
        )
        active_sessions = sessions_resp.get("Count", 0)
        
        return {
            "totalUsers": total_users,
            "totalDevices": total_devices,
            "activeSessions": active_sessions,
            "systemUptime": "99.9%",  # Would come from CloudWatch in production
            "dataStorage": "2.4 TB"   # Would come from S3 metrics
        }
    except Exception as e:
        print(f"Error getting dashboard stats: {e}")
        return {}
