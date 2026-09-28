from fastapi import APIRouter
from services.order_type_service import OrderTypeService


router = APIRouter(
    prefix="/api/order_type",
    tags=["order_type"],
)

order_type_service = OrderTypeService()


@router.get("/")
async def get_order_type():
    return {"order_type": order_type_service.get_all()}
