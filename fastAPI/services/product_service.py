from fastapi import HTTPException
from repositories.product_repository import ProductRepository


class ProductService:
    def __init__(self):
        self.repository = ProductRepository()

    def get_all(self):
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch product")
