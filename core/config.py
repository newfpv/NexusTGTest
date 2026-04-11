import os
import json
import logging
from dotenv import load_dotenv

load_dotenv(override=True)

class AFCFilter(logging.Filter):
    def filter(self, record):
        return "AFC is enabled" not in record.getMessage()

logging.basicConfig(
    level=logging.INFO, 
    format="%(asctime)s | %(levelname)s | %(message)s",
    datefmt="%H:%M",
    force=True
)

logging.getLogger().addFilter(AFCFilter())

logging.getLogger("aiogram.event").setLevel(logging.WARNING)
logging.getLogger("httpx").setLevel(logging.WARNING)

TG_BOT_TOKEN = os.getenv("TG_BOT_TOKEN")
LANG_FILE = os.getenv("LANG_FILE", "language_RU.json")
DB_PATH = "sqlite+aiosqlite:///data/core_database.db"

os.makedirs("data", exist_ok=True)
os.makedirs("modules", exist_ok=True)

# LOCALIZATION (i18n)
translations = {}
CORE_REQUIRED_KEYS = ["btn_back", "btn_cancel", "setup_guide", "test_progress"]

def _flatten_dict(d: dict) -> dict:
    flat = {}
    for k, v in d.items():
        if isinstance(v, dict):
            flat.update(_flatten_dict(v))
        else:
            flat[k] = v
    return flat

def load_language():
    global translations
    if os.path.exists(LANG_FILE):
        try:
            with open(LANG_FILE, 'r', encoding='utf-8') as f:
                translations = _flatten_dict(json.load(f))
            logging.info(f"🌐 i18n: {LANG_FILE} loaded.")
        except Exception as e:
            logging.error(f"❌ i18n Error: {e}")

def _(key: str, **kwargs) -> str:
    if key not in translations:
        logging.warning(f"Missing i18n key: '{key}'")
        text = key
    else:
        text = translations[key]
        
    if kwargs:
        try: return text.format(**kwargs)
        except KeyError as e: 
            logging.warning(f"Missing format argument '{e.args[0]}' in i18n key: '{key}'")
    return text

load_language()