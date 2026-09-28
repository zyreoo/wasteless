from fastapi import HTTPException
from repositories.order_status_repository import OrderStatusRepository


class OrderStatusService:
    def __init__(self):
        self.repository = OrderStatusRepository()

    def get_all(self):
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch order status")
