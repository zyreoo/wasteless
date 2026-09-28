from fastapi import APIRouter
from services.user_service import UserService


router = APIRouter(
    prefix="/api/users",
    tags=["users"],
)

user_service = UserService()


@router.get("/")
async def get_users():
    return {"users": user_service.get_all()}
