from db.supabase_client import supabase


class BaseRepository:
    table_name: str
    columns: str = "*"  # TODO: fiecare repository ar trebui sa suprascrie asta cu doar coloanele necesare
    # clientului (nu tot tabelul), odata ce stim exact ce campuri trebuie expuse. Pana atunci ramane "*"
    # ca sa nu ghicim nume de coloane inexistente.

    def find_all(self):
        return supabase.table(self.table_name).select(self.columns).execute().data

    def find_by_id(self, id_column: str, id_value):
        response = (
            supabase.table(self.table_name)
            .select(self.columns)
            .eq(id_column, id_value)
            .execute()
        )
        return response.data

    def create(self, data: dict):
        return supabase.table(self.table_name).insert(data).execute().data

    def update(self, id_column: str, id_value, data: dict):
        return (
            supabase.table(self.table_name)
            .update(data)
            .eq(id_column, id_value)
            .execute()
            .data
        )

    def delete_by_id(self, id_column: str, id_value):
        return (
            supabase.table(self.table_name)
            .delete()
            .eq(id_column, id_value)
            .execute()
            .data
        )
