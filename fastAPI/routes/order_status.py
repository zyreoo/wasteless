from fastapi import APIRouter
from services.order_status_service import OrderStatusService


router = APIRouter(
    prefix="/api/order_status",
    tags=["order_status"],
)

order_status_service = OrderStatusService()


@router.get("/")
async def get_order_status():
    return {"order_status": order_status_service.get_all()}
