import boto3
import os
from boto3.dynamodb.conditions import Key

# Set environment variables to match production
os.environ["DDB_TABLE_USERS"] = "medusa-users-prod"
os.environ["DDB_TABLE_PATIENT_PROFILES"] = "medusa-patient-profiles-prod"

def test_assign_logic(doctor_id, patient_email):
    print(f"Testing assignment: {patient_email} -> {doctor_id}")
    
    ddb = boto3.resource("dynamodb", region_name="us-east-1")
    users_table = ddb.Table(os.environ["DDB_TABLE_USERS"])
    
    # 1. Simulate get_user_by_email
    print("Querying user by email...")
    try:
        resp = users_table.query(
            IndexName="email-index",
            KeyConditionExpression=Key("email").eq(patient_email),
            Limit=1
        )
        items = resp.get("Items", [])
        if not items:
            print("❌ Patient not found in DB")
            return
        
        patient = items[0]
        print(f"✅ Found patient: {patient['id']}")
        
        # 2. Simulate create_patient_profile
        profiles_table = ddb.Table(os.environ["DDB_TABLE_PATIENT_PROFILES"])
        profile = {
            "userId": patient["id"],
            "doctorId": doctor_id,
            "assignedAt": "2025-12-01T12:00:00Z",
            "status": "active"
        }
        print(f"Attempting to write profile: {profile}")
        profiles_table.put_item(Item=profile)
        print("✅ Profile written successfully")
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    # Use the real data provided by the user
    test_assign_logic("usr_bb15f354", "zsun54@jh.edu")
