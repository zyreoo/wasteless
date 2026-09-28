from fastapi import APIRouter
from services.loyalty_points_service import LoyaltyPointsService


router = APIRouter(
    prefix="/api/loyalty_points",
    tags=["loyalty_points"],
)

loyalty_points_service = LoyaltyPointsService()


@router.get("/")
async def get_loyalty_points():
    return {"loyalty_points": loyalty_points_service.get_all()}
