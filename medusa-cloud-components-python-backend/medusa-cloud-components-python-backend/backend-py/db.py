import os
from typing import Optional, Dict, Any, List, Tuple
import boto3
from boto3.dynamodb.conditions import Key, Attr

def _pose_pk(patient_id: str) -> str:
    return f"POSE#{patient_id}"

def _pose_sk(pose_id: str) -> str:
    return f"POSE#{pose_id}"

USE_MEMORY = os.environ.get("USE_MEMORY", "false").lower() == "true"

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

    USERS_SINGLE_TABLE = _is_pk_sk(USERS_PK_ATTR, USERS_SK_ATTR)
    REFRESH_SINGLE_TABLE = _is_pk_sk(REFRESH_PK_ATTR, REFRESH_SK_ATTR)
    POSES_SINGLE_TABLE = _is_pk_sk(POSES_PK_ATTR, POSES_SK_ATTR)
    DEVICES_SINGLE_TABLE = _is_pk_sk(DEVICES_PK_ATTR, DEVICES_SK_ATTR)
    PROFILES_SINGLE_TABLE = _is_pk_sk(PROFILES_PK_ATTR, PROFILES_SK_ATTR)
    SESSIONS_SINGLE_TABLE = _is_pk_sk(SESSIONS_PK_ATTR, SESSIONS_SK_ATTR)

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
    USERS_SINGLE_TABLE = False
    REFRESH_SINGLE_TABLE = False
    POSES_SINGLE_TABLE = False
    DEVICES_SINGLE_TABLE = False
    PROFILES_SINGLE_TABLE = False
    SESSIONS_SINGLE_TABLE = False
    USERS_PK_ATTR, USERS_SK_ATTR = "id", None
    REFRESH_PK_ATTR, REFRESH_SK_ATTR = "token", None
    POSES_PK_ATTR, POSES_SK_ATTR = "patientId", None

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
    item = resp.get("Item")
    if item:
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
    """Get all patients for a doctor"""
    if USE_MEMORY:
        return [p for p in _patient_profiles.values() if p.get("doctorId") == doctor_id]
    resp = T_PATIENT_PROFILES.query(
        IndexName="doctorId-index",
        KeyConditionExpression=Key("doctorId").eq(doctor_id)
    )
    return resp.get("Items", [])

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
    resp = T_SESSIONS.get_item(Key={"sessionId": session_id})
    return resp.get("Item")

def get_active_session_by_device(device_id: str) -> Optional[Dict[str, Any]]:
    """Get active session for a device"""
    if USE_MEMORY:
        for session in _sessions.values():
            if session.get("deviceId") == device_id and session.get("status") == "active":
                return session
        return None
    
    resp = T_SESSIONS.query(
        IndexName="deviceId-index",
        KeyConditionExpression=Key("deviceId").eq(device_id),
        FilterExpression=Attr("status").eq("active")
    )
    items = resp.get("Items", [])
    return items[0] if items else None

def get_sessions_by_patient(patient_id: str) -> List[Dict[str, Any]]:
    """Get all sessions for a patient"""
    if USE_MEMORY:
        return [s for s in _sessions.values() if s.get("patientId") == patient_id]
    resp = T_SESSIONS.query(
        IndexName="patientId-index",
        KeyConditionExpression=Key("patientId").eq(patient_id)
    )
    return resp.get("Items", [])

def get_sessions_by_device(device_id: str) -> List[Dict[str, Any]]:
    """Get all sessions for a device"""
    if USE_MEMORY:
        return [s for s in _sessions.values() if s.get("deviceId") == device_id]
    resp = T_SESSIONS.query(
        IndexName="deviceId-index",
        KeyConditionExpression=Key("deviceId").eq(device_id)
    )
    return resp.get("Items", [])

def get_active_sessions() -> List[Dict[str, Any]]:
    """Get all active sessions"""
    if USE_MEMORY:
        return [s for s in _sessions.values() if s.get("status") == "active"]
    resp = T_SESSIONS.query(
        IndexName="status-index",
        KeyConditionExpression=Key("status").eq("active")
    )
    return resp.get("Items", [])

def update_session(session_id: str, updates: Dict[str, Any]) -> None:
    """Update session fields"""
    if USE_MEMORY:
        if session_id in _sessions:
            _sessions[session_id].update(updates)
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
    
    T_SESSIONS.update_item(
        Key={"sessionId": session_id},
        UpdateExpression=update_expr,
        ExpressionAttributeNames=expr_attr_names,
        ExpressionAttributeValues=expr_attr_values
    )

def delete_session(session_id: str) -> None:
    """Delete a session"""
    if USE_MEMORY:
        if session_id in _sessions:
            del _sessions[session_id]
        return
    T_SESSIONS.delete_item(Key={"sessionId": session_id})
