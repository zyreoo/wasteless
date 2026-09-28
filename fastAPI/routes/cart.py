from fastapi import APIRouter
from services.cart_service import CartService


router = APIRouter(
    prefix="/api/cart",
    tags=["cart"],
)

cart_service = CartService()


@router.get("/")
async def get_cart():
    return {"cart": cart_service.get_all()}
