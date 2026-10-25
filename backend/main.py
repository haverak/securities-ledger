from models import Deal
from schemas import DealCreate, DealUpdate, DealResponse
from fastapi import Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from sqlalchemy import func

from database import get_db
from models import DealType, DealPlace, Currency
from schemas import (
    NameCreate,
    NameResponse,
    CurrencyCreate,
    CurrencyResponse,
)
from fastapi import FastAPI
from sqlalchemy import text

from database import Base, engine
import models

app = FastAPI(
    title="Securities Ledger API",
    description="Сервер учёта сделок с ценными бумагами",
    version="1.0.0",
)


@app.on_event("startup")
def startup():
    Base.metadata.create_all(bind=engine)


@app.get("/")
def root():
    return {
        "application": "Securities Ledger",
        "status": "running",
    }


@app.get("/health")
def health():
    with engine.connect() as connection:
        connection.execute(text("SELECT 1"))

    return {
        "status": "ok",
        "database": "connected",
    }

@app.get("/deal-types", response_model=list[NameResponse])
def list_deal_types(db: Session = Depends(get_db)):
    return db.scalars(select(DealType).order_by(DealType.id)).all()


@app.post(
    "/deal-types",
    response_model=NameResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_deal_type(
    data: NameCreate,
    db: Session = Depends(get_db),
):
    item = DealType(name=data.name.strip())
    if not item.name:
        raise HTTPException(422, "Название не может быть пустым")

    db.add(item)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Такой тип сделки уже существует")

    db.refresh(item)
    return item


@app.get("/deal-places", response_model=list[NameResponse])
def list_deal_places(db: Session = Depends(get_db)):
    return db.scalars(select(DealPlace).order_by(DealPlace.id)).all()


@app.post(
    "/deal-places",
    response_model=NameResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_deal_place(
    data: NameCreate,
    db: Session = Depends(get_db),
):
    item = DealPlace(name=data.name.strip())
    if not item.name:
        raise HTTPException(422, "Название не может быть пустым")

    db.add(item)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Такая площадка уже существует")

    db.refresh(item)
    return item


@app.get("/currencies", response_model=list[CurrencyResponse])
def list_currencies(db: Session = Depends(get_db)):
    return db.scalars(select(Currency).order_by(Currency.id)).all()


@app.post(
    "/currencies",
    response_model=CurrencyResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_currency(
    data: CurrencyCreate,
    db: Session = Depends(get_db),
):
    item = Currency(
        code=data.code.upper(),
        name=data.name.strip(),
    )
    if not item.name:
        raise HTTPException(422, "Название не может быть пустым")

    db.add(item)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Такая валюта уже существует")

    db.refresh(item)
    return item

def validate_deal_references(db: Session, data: DealCreate):
    checks = [
        (DealType, data.deal_type_id, "Тип сделки"),
        (DealPlace, data.deal_place_id, "Место сделки"),
        (Currency, data.currency_id, "Валюта"),
    ]
    for model, item_id, label in checks:
        if db.get(model, item_id) is None:
            raise HTTPException(
                status_code=422,
                detail=f"{label}: запись с ID {item_id} не найдена",
            )


@app.get("/deals", response_model=list[DealResponse])
def list_deals(db: Session = Depends(get_db)):
    return db.scalars(
        select(Deal).order_by(Deal.deal_date.desc(), Deal.id.desc())
    ).all()


@app.get("/deals/{deal_id}", response_model=DealResponse)
def get_deal(deal_id: int, db: Session = Depends(get_db)):
    deal = db.get(Deal, deal_id)
    if deal is None:
        raise HTTPException(404, "Сделка не найдена")
    return deal


@app.post(
    "/deals",
    response_model=DealResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_deal(
    data: DealCreate,
    db: Session = Depends(get_db),
):
    validate_deal_references(db, data)
    values = data.model_dump()
    values["security_name"] = values["security_name"].strip()
    if not values["security_name"]:
        raise HTTPException(422, "Название ценной бумаги пустое")

    deal = Deal(**values)
    db.add(deal)
    db.commit()
    db.refresh(deal)
    return deal


@app.put("/deals/{deal_id}", response_model=DealResponse)
def update_deal(
    deal_id: int,
    data: DealUpdate,
    db: Session = Depends(get_db),
):
    deal = db.get(Deal, deal_id)
    if deal is None:
        raise HTTPException(404, "Сделка не найдена")

    validate_deal_references(db, data)
    values = data.model_dump()
    values["security_name"] = values["security_name"].strip()
    if not values["security_name"]:
        raise HTTPException(422, "Название ценной бумаги пустое")

    for key, value in values.items():
        setattr(deal, key, value)

    db.commit()
    db.refresh(deal)
    return deal


@app.delete("/deals/{deal_id}", status_code=204)
def delete_deal(
    deal_id: int,
    db: Session = Depends(get_db),
):
    deal = db.get(Deal, deal_id)
    if deal is None:
        raise HTTPException(404, "Сделка не найдена")

    db.delete(deal)
    db.commit()

# Редактирование справочников

def update_reference(db, model, item_id, values):
    item = db.get(model, item_id)

    if item is None:
        raise HTTPException(404, "Запись справочника не найдена")

    for key, value in values.items():
        setattr(item, key, value)

    try:
        db.commit()
        db.refresh(item)
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Такая запись уже существует")

    return item


@app.put("/deal-types/{item_id}", response_model=NameResponse)
def update_deal_type(
    item_id: int,
    data: NameCreate,
    db: Session = Depends(get_db),
):
    name = data.name.strip()
    if not name or len(name) > 100:
        raise HTTPException(422, "Название: от 1 до 100 символов")
    return update_reference(db, DealType, item_id, {"name": name})


@app.put("/deal-places/{item_id}", response_model=NameResponse)
def update_deal_place(
    item_id: int,
    data: NameCreate,
    db: Session = Depends(get_db),
):
    name = data.name.strip()
    if not name:
        raise HTTPException(422, "Название не может быть пустым")
    return update_reference(db, DealPlace, item_id, {"name": name})


@app.put("/currencies/{item_id}", response_model=CurrencyResponse)
def update_currency(
    item_id: int,
    data: CurrencyCreate,
    db: Session = Depends(get_db),
):
    name = data.name.strip()
    if not name:
        raise HTTPException(422, "Название не может быть пустым")
    return update_reference(
        db,
        Currency,
        item_id,
        {"code": data.code.upper(), "name": name},
    )


# Удаление с проверкой связанных сделок

def delete_reference(db, model, item_id, foreign_key):
    item = db.get(model, item_id)

    if item is None:
        raise HTTPException(404, "Запись справочника не найдена")

    used = db.scalar(
        select(func.count(Deal.id)).where(foreign_key == item_id)
    )

    if used:
        raise HTTPException(
            409,
            f"Нельзя удалить: запись используется в {used} сделках",
        )

    db.delete(item)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Запись связана с другими данными")


@app.delete("/deal-types/{item_id}", status_code=204)
def delete_deal_type(
    item_id: int,
    db: Session = Depends(get_db),
):
    delete_reference(db, DealType, item_id, Deal.deal_type_id)


@app.delete("/deal-places/{item_id}", status_code=204)
def delete_deal_place(
    item_id: int,
    db: Session = Depends(get_db),
):
    delete_reference(db, DealPlace, item_id, Deal.deal_place_id)


@app.delete("/currencies/{item_id}", status_code=204)
def delete_currency(
    item_id: int,
    db: Session = Depends(get_db),
):
    delete_reference(db, Currency, item_id, Deal.currency_id)
