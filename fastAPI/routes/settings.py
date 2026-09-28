from fastapi import APIRouter
from services.settings_service import SettingsService


router = APIRouter(
    prefix="/api/settings",
    tags=["settings"],
)

settings_service = SettingsService()


@router.get("/")
async def get_settings():
    return {"settings": settings_service.get_all()}
