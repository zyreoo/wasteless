from fastapi import APIRouter
from services.locations_service import LocationsService


router = APIRouter(
    prefix="/api/locations",
    tags=["locations"],
)

locations_service = LocationsService()


@router.get("/")
async def get_locations():
    return {"locations": locations_service.get_all()}
