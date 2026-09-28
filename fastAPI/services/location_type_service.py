from fastapi import HTTPException
from repositories.location_type_repository import LocationTypeRepository


class LocationTypeService:
    def __init__(self):
        self.repository = LocationTypeRepository()

    def get_all(self):
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch location types")
