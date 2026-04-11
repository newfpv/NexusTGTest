import os
from datetime import datetime
from typing import Any, Dict, Optional
from sqlalchemy import String, Integer, Boolean, Float, DateTime, Text, JSON, BigInteger, text
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.orm.attributes import flag_modified  # <-- ВАЖНЫЙ ИМПОРТ
from core.config import DB_PATH

engine = create_async_engine(DB_PATH, echo=False)
AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

class Base(DeclarativeBase): pass

class GlobalConfig(Base):
    __tablename__ = "global_config"
    id: Mapped[int] = mapped_column(primary_key=True, default=1)
    is_setup_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    admin_id: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)
    admin_menu_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    tz: Mapped[Optional[str]] = mapped_column(String, default="Europe/London")
    api_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    api_hash: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    api_keys: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    model_fallback_list: Mapped[Optional[str]] = mapped_column(Text, default="gemini-1.5-flash,gemini-2.0-flash-exp")
    phone: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    session_string: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    global_ai_active: Mapped[bool] = mapped_column(Boolean, default=False)
    google_search: Mapped[bool] = mapped_column(Boolean, default=True)
    global_prompt: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    typing_speed: Mapped[float] = mapped_column(Float, default=0.10)
    sleep_start: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    sleep_end: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    module_settings: Mapped[Dict[str, Any]] = mapped_column(JSON, default=dict)

class ChatConfig(Base):
    __tablename__ = "chat_config"
    chat_id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=False)
    custom_prompt: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    delay_before_min: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    delay_before_max: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    delay_after_min: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    delay_after_max: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    is_ignored: Mapped[bool] = mapped_column(Boolean, default=False)
    module_data: Mapped[Dict[str, Any]] = mapped_column(JSON, default=dict)

class IgnoredMessage(Base):
    __tablename__ = "ignored_msgs"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    chat_id: Mapped[int] = mapped_column(BigInteger, index=True)
    message_id: Mapped[int] = mapped_column(BigInteger, index=True)

class YoutubeCache(Base):
    __tablename__ = "youtube_cache"
    video_id: Mapped[str] = mapped_column(String, primary_key=True)
    duration: Mapped[int] = mapped_column(Integer, default=0)
    context: Mapped[str] = mapped_column(Text)
    timestamp: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class MediaMemoryCache(Base):
    __tablename__ = "media_memory_cache"
    msg_id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    media_type: Mapped[str] = mapped_column(String)
    content: Mapped[str] = mapped_column(Text)
    timestamp: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class AICmdTracker(Base):
    __tablename__ = "ai_cmd_tracker"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    chat_id: Mapped[int] = mapped_column(BigInteger, index=True)
    msg_id: Mapped[int] = mapped_column(BigInteger, index=True)

class CoreRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_global_config(self) -> GlobalConfig:
        obj = await self.session.get(GlobalConfig, 1)
        if not obj:
            obj = GlobalConfig(id=1)
            self.session.add(obj)
            await self.session.flush()
        return obj

    async def update_global_config(self, **kwargs):
        obj = await self.get_global_config()
        for key, value in kwargs.items():
            setattr(obj, key, value)
        await self.session.commit()

    async def save_session(self, phone: str, session_string: str):
        conf = await self.get_global_config()
        conf.phone = phone
        conf.session_string = session_string
        await self.session.commit()

    async def delete_session(self):
        conf = await self.get_global_config()
        conf.phone = None
        conf.session_string = None
        await self.session.commit()

    async def full_reset(self):
        conf = await self.get_global_config()
        conf.phone = None
        conf.session_string = None
        conf.api_id = None
        conf.api_hash = None
        conf.api_keys = None
        conf.admin_id = None
        conf.admin_menu_id = None
        conf.is_setup_completed = False
        await self.session.commit()

    async def get_chat_config(self, chat_id: int) -> ChatConfig:
        obj = await self.session.get(ChatConfig, chat_id)
        if not obj:
            obj = ChatConfig(chat_id=chat_id)
            self.session.add(obj)
            await self.session.flush()
        return obj

    async def update_chat_config(self, chat_id: int, **kwargs):
        obj = await self.get_chat_config(chat_id)
        for k, v in kwargs.items(): 
            setattr(obj, k, v)
        await self.session.commit()

    async def add_ignored_msg(self, chat_id: int, message_id: int):
        self.session.add(IgnoredMessage(chat_id=chat_id, message_id=message_id))
        await self.session.commit()

    async def is_msg_ignored(self, chat_id: int, message_id: int) -> bool:
        from sqlalchemy import select
        res = await self.session.execute(select(IgnoredMessage).where(
            IgnoredMessage.chat_id == chat_id, 
            IgnoredMessage.message_id == message_id
        ))
        return res.scalar_one_or_none() is not None

    async def save_media_memory(self, msg_id: int, m_type: str, content: str):
        from sqlalchemy.dialects.sqlite import insert
        stmt = insert(MediaMemoryCache).values(
            msg_id=msg_id, media_type=m_type, content=content, timestamp=datetime.utcnow()
        )
        stmt = stmt.on_conflict_do_update(
            index_elements=['msg_id'], 
            set_={'content': content, 'timestamp': datetime.utcnow()}
        )
        await self.session.execute(stmt)
        await self.session.commit()

    async def get_media_memory(self, msg_id: int, m_type: str) -> Optional[str]:
        from sqlalchemy import select
        res = await self.session.execute(select(MediaMemoryCache.content).where(
            MediaMemoryCache.msg_id == msg_id, 
            MediaMemoryCache.media_type == m_type
        ))
        return res.scalar_one_or_none()

    async def track_ai_message(self, chat_id: int, msg_id: int):
        self.session.add(AICmdTracker(chat_id=chat_id, msg_id=msg_id))
        await self.session.commit()

    async def get_module_cfg(self, module_name: str) -> dict:
        c = await self.get_global_config()
        return c.module_settings.get(module_name, {})

    async def update_module_cfg(self, module_name: str, **kwargs):
        c = await self.get_global_config()
        settings = dict(c.module_settings)
        mod_cfg = settings.get(module_name, {})
        mod_cfg.update(kwargs)
        settings[module_name] = mod_cfg
        c.module_settings = settings
        flag_modified(c, "module_settings")
        await self.session.commit()

    async def get_chat_module_cfg(self, chat_id: int, module_name: str) -> dict:
        c = await self.get_chat_config(chat_id)
        return c.module_data.get(module_name, {})

    async def update_chat_module_cfg(self, chat_id: int, module_name: str, **kwargs):
        c = await self.get_chat_config(chat_id)
        settings = dict(c.module_data)
        mod_cfg = settings.get(module_name, {})
        mod_cfg.update(kwargs)
        settings[module_name] = mod_cfg
        c.module_data = settings
        flag_modified(c, "module_data")
        await self.session.commit()

async def init_db():
    os.makedirs("data", exist_ok=True)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        try:
            await conn.execute(text("ALTER TABLE global_config ADD COLUMN admin_menu_id INTEGER"))
            await conn.commit()
        except Exception:
            pass

class DatabaseMiddleware:
    async def __call__(self, handler, event, data):
        async with AsyncSessionLocal() as session:
            data['session'] = session
            data['repo'] = CoreRepository(session)
            return await handler(event, data)