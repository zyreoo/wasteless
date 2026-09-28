from fastapi import APIRouter
from services.order_service import OrderService


router = APIRouter(
    prefix="/api/order",
    tags=["order"],
)

order_service = OrderService()


@router.get("/")
async def get_order():
    return {"order": order_service.get_all()}
