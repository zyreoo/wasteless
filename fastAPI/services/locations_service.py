from fastapi import HTTPException
from repositories.locations_repository import LocationsRepository


class LocationsService:
    def __init__(self):
        self.repository = LocationsRepository()

    def get_all(self):
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch locations")
