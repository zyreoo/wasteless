from fastapi import APIRouter
from services.cart_items_service import CartItemsService


router = APIRouter(
    prefix="/api/cart_items",
    tags=["cart_items"],
)

cart_items_service = CartItemsService()


@router.get("/")
async def get_cart_items():
    return {"cart_items": cart_items_service.get_all()}
