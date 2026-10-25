
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import Base


class DealType(Base):
    __tablename__ = "deal_types"

    id: Mapped[int] = mapped_column(
        Integer, primary_key=True
    )
    name: Mapped[str] = mapped_column(
        String(100), unique=True, nullable=False
    )


class DealPlace(Base):
    __tablename__ = "deal_places"

    id: Mapped[int] = mapped_column(
        Integer, primary_key=True
    )
    name: Mapped[str] = mapped_column(
        String(150), unique=True, nullable=False
    )


class Currency(Base):
    __tablename__ = "currencies"

    id: Mapped[int] = mapped_column(
        Integer, primary_key=True
    )
    code: Mapped[str] = mapped_column(
        String(3), unique=True, nullable=False
    )
    name: Mapped[str] = mapped_column(
        String(100), nullable=False
    )


class Deal(Base):
    __tablename__ = "deals"

    id: Mapped[int] = mapped_column(
        Integer, primary_key=True
    )

    security_name: Mapped[str] = mapped_column(
        String(200), nullable=False
    )

    quantity: Mapped[int] = mapped_column(
        Integer, nullable=False
    )

    price: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False
    )

    deal_date: Mapped[datetime] = mapped_column(
        DateTime, nullable=False
    )

    deal_type_id: Mapped[int] = mapped_column(
        ForeignKey("deal_types.id"), nullable=False
    )

    deal_place_id: Mapped[int] = mapped_column(
        ForeignKey("deal_places.id"), nullable=False
    )

    currency_id: Mapped[int] = mapped_column(
        ForeignKey("currencies.id"), nullable=False
    )

    deal_type: Mapped[DealType] = relationship()
    deal_place: Mapped[DealPlace] = relationship()
    currency: Mapped[Currency] = relationship()
