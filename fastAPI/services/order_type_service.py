from fastapi import HTTPException
from repositories.order_type_repository import OrderTypeRepository


class OrderTypeService:
    def __init__(self):
        self.repository = OrderTypeRepository()

    def get_all(self):
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch order type")
