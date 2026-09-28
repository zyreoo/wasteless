from fastapi import APIRouter
from services.offer_items_service import OfferItemsService


router = APIRouter(
    prefix="/api/offer_items",
    tags=["offer_items"],
)

offer_items_service = OfferItemsService()


@router.get("/")
async def get_offer_items():
    return {"offer_items": offer_items_service.get_all()}
