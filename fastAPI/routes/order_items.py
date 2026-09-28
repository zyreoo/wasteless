from fastapi import APIRouter
from services.order_items_service import OrderItemsService


router = APIRouter(
    prefix="/api/order_items",
    tags=["order_items"],
)

order_items_service = OrderItemsService()


@router.get("/")
async def get_order_items():
    return {"order_items": order_items_service.get_all()}
