#aici tinem conexiunea cu supabase, sa nu o cream de fiecare data cand facem un request

import os
from dotenv import load_dotenv
from supabase import create_client, Client, ClientOptions


load_dotenv()


SUPABASE_URL_ENV = "SUPABASE_URL"
SUPABASE_SECRET_KEY_ENV = "SUPABASE_SECRET_KEY"
SUPABASE_SCHEMA = "public" #definita ca si constanta, nu ca string direct: reutilizabila si elimina greselile de neatentie/oboseala (ex: typo "publi") sau nevoia de a cauta prin tot proiectul daca schimbam schema

url = os.getenv(SUPABASE_URL_ENV)
key = os.getenv(SUPABASE_SECRET_KEY_ENV) #aici luam url-ul si cheia din variabilele de mediu, astfel incat sa nu fie hardcodate in codul sursa

if not url:
    raise ValueError(f"{SUPABASE_URL_ENV} environment variable is not set")

if not key:
    raise ValueError(f"{SUPABASE_SECRET_KEY_ENV} environment variable is not set")

options = ClientOptions(schema=SUPABASE_SCHEMA) #schema specificata explicit prin constanta, nu ca string hardcodat

supabase: Client = create_client(
    url, key, options=options 
    ) #aici cream conexiunea cu supabase, folosind url-ul si cheia din variabilele de mediu
