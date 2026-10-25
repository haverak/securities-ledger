from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, ConfigDict, Field


class NameCreate(BaseModel):
    name: str = Field(min_length=1, max_length=150)


class NameResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str


class CurrencyCreate(BaseModel):
    code: str = Field(
        min_length=3,
        max_length=3,
        pattern=r"^[A-Za-z]{3}$",
    )
    name: str = Field(min_length=1, max_length=100)


class CurrencyResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    code: str
    name: str

class DealCreate(BaseModel):
    security_name: str = Field(min_length=1, max_length=200)
    quantity: int = Field(gt=0)
    price: Decimal = Field(gt=0, max_digits=18, decimal_places=4)
    deal_date: datetime
    deal_type_id: int = Field(gt=0)
    deal_place_id: int = Field(gt=0)
    currency_id: int = Field(gt=0)


class DealUpdate(DealCreate):
    pass


class DealResponse(DealCreate):
    model_config = ConfigDict(from_attributes=True)

    id: int
