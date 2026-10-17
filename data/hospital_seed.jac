"""Typed, fictional Sri Lankan hospital seed data for the CareRoute demo.

Names, phone numbers, credentials, and bed counts are synthetic. Coordinates
are placed near major Sri Lankan cities so routing and matching demos remain
realistic without representing live hospital availability.
"""

import from models { Sector, UnitType }


glob DEMO_HOSPITAL_PASSWORD = "care-route-demo";


obj UnitSeed {
    has unit_type: UnitType,
        total_beds: int,
        free_beds: int;
}


obj HospitalSeed {
    has hospital_id: str,
        name: str,
        sector: Sector,
        city: str,
        lat: float,
        lon: float,
        phone: str,
        username: str,
        units: list[UnitSeed];
}


"""Return fresh seed objects so callers can safely adjust demo beds."""
def hospital_seed_data -> list[HospitalSeed] {
    return [
        HospitalSeed(
            hospital_id="demo-colombo-central",
            name="Colombo Central Care Hospital (Demo)",
            sector=Sector.PUBLIC,
            city="Colombo",
            lat=6.9271,
            lon=79.8612,
            phone="000-000-0001",
            username="colombo_central_demo",
            units=[
                UnitSeed(unit_type=UnitType.CARDIAC, total_beds=28, free_beds=6),
                UnitSeed(unit_type=UnitType.TRAUMA, total_beds=24, free_beds=4),
                UnitSeed(unit_type=UnitType.ICU, total_beds=18, free_beds=3),
                UnitSeed(unit_type=UnitType.NEURO, total_beds=16, free_beds=2),
                UnitSeed(unit_type=UnitType.GENERAL, total_beds=80, free_beds=15),
            ],
        ),
        HospitalSeed(
            hospital_id="demo-lanka-heart",
            name="Lanka Heart and Neuro Centre (Demo)",
            sector=Sector.PRIVATE,
            city="Colombo",
            lat=6.9147,
            lon=79.8776,
            phone="000-000-0002",
            username="lanka_heart_demo",
            units=[
                UnitSeed(unit_type=UnitType.CARDIAC, total_beds=22, free_beds=5),
                UnitSeed(unit_type=UnitType.ICU, total_beds=14, free_beds=2),
                UnitSeed(unit_type=UnitType.NEURO, total_beds=12, free_beds=3),
                UnitSeed(unit_type=UnitType.GENERAL, total_beds=36, free_beds=8),
            ],
        ),
        HospitalSeed(
            hospital_id="demo-kotte-emergency",
            name="Kotte Emergency and Trauma Hospital (Demo)",
            sector=Sector.PUBLIC,
            city="Sri Jayewardenepura Kotte",
            lat=6.8941,
            lon=79.9025,
            phone="000-000-0003",
            username="kotte_emergency_demo",
            units=[
                UnitSeed(unit_type=UnitType.TRAUMA, total_beds=26, free_beds=7),
                UnitSeed(unit_type=UnitType.ICU, total_beds=16, free_beds=4),
                UnitSeed(unit_type=UnitType.NEURO, total_beds=10, free_beds=1),
                UnitSeed(unit_type=UnitType.GENERAL, total_beds=64, free_beds=10),
            ],
        ),
        HospitalSeed(
            hospital_id="demo-western-medical",
            name="Western Lakes Medical Centre (Demo)",
            sector=Sector.PRIVATE,
            city="Dehiwala-Mount Lavinia",
            lat=6.8301,
            lon=79.8801,
            phone="000-000-0004",
            username="western_lakes_demo",
            units=[
                UnitSeed(unit_type=UnitType.CARDIAC, total_beds=12, free_beds=1),
                UnitSeed(unit_type=UnitType.TRAUMA, total_beds=10, free_beds=2),
                UnitSeed(unit_type=UnitType.ICU, total_beds=10, free_beds=0),
                UnitSeed(unit_type=UnitType.GENERAL, total_beds=42, free_beds=9),
            ],
        ),
        HospitalSeed(
            hospital_id="demo-kandy-regional",
            name="Kandy Regional Care Hospital (Demo)",
            sector=Sector.PUBLIC,
            city="Kandy",
            lat=7.2906,
            lon=80.6337,
            phone="000-000-0005",
            username="kandy_regional_demo",
            units=[
                UnitSeed(unit_type=UnitType.CARDIAC, total_beds=18, free_beds=4),
                UnitSeed(unit_type=UnitType.TRAUMA, total_beds=20, free_beds=5),
                UnitSeed(unit_type=UnitType.ICU, total_beds=14, free_beds=2),
                UnitSeed(unit_type=UnitType.NEURO, total_beds=12, free_beds=2),
                UnitSeed(unit_type=UnitType.GENERAL, total_beds=70, free_beds=13),
            ],
        ),
        HospitalSeed(
            hospital_id="demo-galle-coastal",
            name="Galle Coastal General Hospital (Demo)",
            sector=Sector.PUBLIC,
            city="Galle",
            lat=6.0535,
            lon=80.2210,
            phone="000-000-0006",
            username="galle_coastal_demo",
            units=[
                UnitSeed(unit_type=UnitType.CARDIAC, total_beds=14, free_beds=3),
                UnitSeed(unit_type=UnitType.TRAUMA, total_beds=22, free_beds=6),
                UnitSeed(unit_type=UnitType.ICU, total_beds=12, free_beds=2),
                UnitSeed(unit_type=UnitType.NEURO, total_beds=8, free_beds=1),
                UnitSeed(unit_type=UnitType.GENERAL, total_beds=60, free_beds=12),
            ],
        ),
        HospitalSeed(
            hospital_id="demo-jaffna-northern",
            name="Jaffna Northern Care Hospital (Demo)",
            sector=Sector.PUBLIC,
            city="Jaffna",
            lat=9.6615,
            lon=80.0255,
            phone="000-000-0007",
            username="jaffna_northern_demo",
            units=[
                UnitSeed(unit_type=UnitType.CARDIAC, total_beds=12, free_beds=2),
                UnitSeed(unit_type=UnitType.TRAUMA, total_beds=16, free_beds=3),
                UnitSeed(unit_type=UnitType.ICU, total_beds=10, free_beds=2),
                UnitSeed(unit_type=UnitType.NEURO, total_beds=8, free_beds=2),
                UnitSeed(unit_type=UnitType.GENERAL, total_beds=52, free_beds=11),
            ],
        ),
        HospitalSeed(
            hospital_id="demo-kurunegala-medical",
            name="Kurunegala Community Medical Centre (Demo)",
            sector=Sector.PRIVATE,
            city="Kurunegala",
            lat=7.4863,
            lon=80.3623,
            phone="000-000-0008",
            username="kurunegala_medical_demo",
            units=[
                UnitSeed(unit_type=UnitType.CARDIAC, total_beds=10, free_beds=2),
                UnitSeed(unit_type=UnitType.TRAUMA, total_beds=12, free_beds=4),
                UnitSeed(unit_type=UnitType.ICU, total_beds=8, free_beds=1),
                UnitSeed(unit_type=UnitType.GENERAL, total_beds=34, free_beds=7),
            ],
        ),
        HospitalSeed(
            hospital_id="demo-anuradhapura-heritage",
            name="Anuradhapura Heritage Hospital (Demo)",
            sector=Sector.PUBLIC,
            city="Anuradhapura",
            lat=8.3114,
            lon=80.4037,
            phone="000-000-0009",
            username="anuradhapura_heritage_demo",
            units=[
                UnitSeed(unit_type=UnitType.CARDIAC, total_beds=12, free_beds=3),
                UnitSeed(unit_type=UnitType.TRAUMA, total_beds=18, free_beds=5),
                UnitSeed(unit_type=UnitType.ICU, total_beds=10, free_beds=2),
                UnitSeed(unit_type=UnitType.NEURO, total_beds=8, free_beds=1),
                UnitSeed(unit_type=UnitType.GENERAL, total_beds=56, free_beds=14),
            ],
        ),
        HospitalSeed(
            hospital_id="demo-matara-southern",
            name="Matara Southern Medical Centre (Demo)",
            sector=Sector.PRIVATE,
            city="Matara",
            lat=5.9549,
            lon=80.5550,
            phone="000-000-0010",
            username="matara_southern_demo",
            units=[
                UnitSeed(unit_type=UnitType.CARDIAC, total_beds=10, free_beds=1),
                UnitSeed(unit_type=UnitType.TRAUMA, total_beds=12, free_beds=3),
                UnitSeed(unit_type=UnitType.ICU, total_beds=8, free_beds=2),
                UnitSeed(unit_type=UnitType.NEURO, total_beds=6, free_beds=1),
                UnitSeed(unit_type=UnitType.GENERAL, total_beds=30, free_beds=6),
            ],
        ),
    ];
}


