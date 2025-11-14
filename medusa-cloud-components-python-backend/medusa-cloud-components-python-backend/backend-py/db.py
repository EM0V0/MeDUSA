import os
from typing import Optional, Dict, Any, List, Tuple
import boto3
from boto3.dynamodb.conditions import Key

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

    USERS_SINGLE_TABLE = _is_pk_sk(USERS_PK_ATTR, USERS_SK_ATTR)
    REFRESH_SINGLE_TABLE = _is_pk_sk(REFRESH_PK_ATTR, REFRESH_SK_ATTR)
    POSES_SINGLE_TABLE = _is_pk_sk(POSES_PK_ATTR, POSES_SK_ATTR)

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
    USERS_SINGLE_TABLE = False
    REFRESH_SINGLE_TABLE = False
    POSES_SINGLE_TABLE = False
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
