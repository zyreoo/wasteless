from fastapi import APIRouter
from services.offers_service import OffersService


router = APIRouter(
    prefix="/api/offers",
    tags=["offers"],
)

offers_service = OffersService()


@router.get("/")
async def get_offers():
    return {"offers": offers_service.get_all()}
