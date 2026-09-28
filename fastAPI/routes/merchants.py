from fastapi import APIRouter
from services.merchants_service import MerchantsService


router = APIRouter(
    prefix="/api/merchants",
    tags=["merchants"],
)

merchants_service = MerchantsService()


@router.get("/")
async def get_merchants():
    return {"merchants": merchants_service.get_all()}
