from fastapi import APIRouter
from services.product_service import ProductService


router = APIRouter(
    prefix="/api/product",
    tags=["product"],
)

product_service = ProductService()


@router.get("/")
async def get_product():
    return {"product": product_service.get_all()}
