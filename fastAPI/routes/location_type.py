from fastapi import APIRouter
from services.location_type_service import LocationTypeService


router = APIRouter(
    prefix="/api/location_type",
    tags=["location_type"],
)

location_type_service = LocationTypeService()


@router.get("/")
async def get_location_type():
    return {"location_type": location_type_service.get_all()}
