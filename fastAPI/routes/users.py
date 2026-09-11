from fastapi import APIRouter
from db.supabase_client import supabase


router = APIRouter(
    prefix="/api/users", 
    tags=["users"],
)
@router.get("/")
async def get_users():
    try:
        response = supabase.auth.admin.list_users()
        return {"users": response} 
    except Exception as e:
        return {"error": str(e)}
    