from fastapi import APIRouter
from services.favorite_service import FavoriteService


router = APIRouter(
    prefix="/api/favorite",
    tags=["favorite"],
)

favorite_service = FavoriteService()


@router.get("/")
async def get_favorite():
    return {"favorite": favorite_service.get_all()}
