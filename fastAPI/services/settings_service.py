from fastapi import HTTPException
from repositories.settings_repository import SettingsRepository


class SettingsService:
    def __init__(self):
        self.repository = SettingsRepository()

    def get_all(self):
        # TODO: verifica daca "settings" sunt globale (setari ale aplicatiei) sau per-utilizator;
        # daca sunt per-utilizator, adauga filtrare dupa user_id odata ce exista autentificare
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch settings")
