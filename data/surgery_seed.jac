"""Fictional surgery waiting-list data for the CareRoute demo.

The catalog lists planned surgeries that commonly have waiting lists in Sri Lanka.
The numbers per hospital are invented for the demo: public hospitals have long
lists, private ones short lists. Hospitals keep their own numbers up to date.
"""

"""One surgery a patient can apply for."""
obj SurgeryInfo {
    has code: str,
        name: str,
        speciality: str,
        description: str;
}

"""A surgery a hospital offers: patients waiting and operations done per week."""
obj SurgeryOffer {
    has code: str,
        waiting: int,
        weekly_capacity: int;
}

glob SURGERY_CATALOG: list[SurgeryInfo] = [
    SurgeryInfo(code="CATARACT", name="Cataract surgery", speciality="Eye", description="Replaces a cloudy eye lens. The most common planned operation in Sri Lanka."),
    SurgeryInfo(code="HERNIA", name="Hernia repair", speciality="General surgery", description="Repairs a bulge in the abdominal wall."),
    SurgeryInfo(code="GALLBLADDER", name="Gallbladder removal", speciality="General surgery", description="Removes the gallbladder, usually through small cuts."),
    SurgeryInfo(code="KNEE", name="Knee replacement", speciality="Orthopaedics", description="Replaces a worn knee joint."),
    SurgeryInfo(code="HIP", name="Hip replacement", speciality="Orthopaedics", description="Replaces a worn hip joint."),
    SurgeryInfo(code="TONSIL", name="Tonsil removal", speciality="Ear, nose and throat", description="Removes the tonsils after repeated infections."),
    SurgeryInfo(code="KIDNEY_STONE", name="Kidney stone removal", speciality="Urology", description="Removes or breaks up stones in the kidney or ureter."),
    SurgeryInfo(code="BYPASS", name="Heart bypass", speciality="Cardiac", description="Reroutes blood around blocked heart arteries."),
    SurgeryInfo(code="THYROID", name="Thyroid surgery", speciality="Endocrine", description="Removes all or part of the thyroid gland.")
];

glob SURGERY_OFFERS: dict[str, list[SurgeryOffer]] = {
    "Colombo Central Care Hospital (Demo)": [
        SurgeryOffer(code="CATARACT", waiting=420, weekly_capacity=30),
        SurgeryOffer(code="HERNIA", waiting=160, weekly_capacity=12),
        SurgeryOffer(code="GALLBLADDER", waiting=210, weekly_capacity=14),
        SurgeryOffer(code="KNEE", waiting=340, weekly_capacity=6),
        SurgeryOffer(code="HIP", waiting=280, weekly_capacity=5),
        SurgeryOffer(code="TONSIL", waiting=120, weekly_capacity=15),
        SurgeryOffer(code="KIDNEY_STONE", waiting=90, weekly_capacity=10),
        SurgeryOffer(code="BYPASS", waiting=85, weekly_capacity=4),
        SurgeryOffer(code="THYROID", waiting=60, weekly_capacity=6)
    ],
    "Lanka Heart and Neuro Centre (Demo)": [
        SurgeryOffer(code="BYPASS", waiting=14, weekly_capacity=6),
        SurgeryOffer(code="CATARACT", waiting=25, weekly_capacity=20),
        SurgeryOffer(code="KNEE", waiting=20, weekly_capacity=8),
        SurgeryOffer(code="HIP", waiting=12, weekly_capacity=6)
    ],
    "Kotte Emergency and Trauma Hospital (Demo)": [
        SurgeryOffer(code="KNEE", waiting=150, weekly_capacity=5),
        SurgeryOffer(code="HIP", waiting=190, weekly_capacity=6),
        SurgeryOffer(code="HERNIA", waiting=80, weekly_capacity=10),
        SurgeryOffer(code="GALLBLADDER", waiting=70, weekly_capacity=8)
    ],
    "Western Lakes Medical Centre (Demo)": [
        SurgeryOffer(code="CATARACT", waiting=18, weekly_capacity=25),
        SurgeryOffer(code="TONSIL", waiting=10, weekly_capacity=12),
        SurgeryOffer(code="HERNIA", waiting=14, weekly_capacity=12),
        SurgeryOffer(code="GALLBLADDER", waiting=12, weekly_capacity=10),
        SurgeryOffer(code="THYROID", waiting=9, weekly_capacity=5),
        SurgeryOffer(code="KIDNEY_STONE", waiting=11, weekly_capacity=8)
    ],
    "Kandy Regional Care Hospital (Demo)": [
        SurgeryOffer(code="CATARACT", waiting=310, weekly_capacity=25),
        SurgeryOffer(code="HERNIA", waiting=140, weekly_capacity=10),
        SurgeryOffer(code="GALLBLADDER", waiting=180, weekly_capacity=10),
        SurgeryOffer(code="KNEE", waiting=220, weekly_capacity=5),
        SurgeryOffer(code="TONSIL", waiting=90, weekly_capacity=12),
        SurgeryOffer(code="KIDNEY_STONE", waiting=70, weekly_capacity=8),
        SurgeryOffer(code="THYROID", waiting=45, weekly_capacity=4),
        SurgeryOffer(code="BYPASS", waiting=60, weekly_capacity=3)
    ],
    "Galle Coastal General Hospital (Demo)": [
        SurgeryOffer(code="CATARACT", waiting=260, weekly_capacity=22),
        SurgeryOffer(code="HERNIA", waiting=100, weekly_capacity=9),
        SurgeryOffer(code="GALLBLADDER", waiting=130, weekly_capacity=8),
        SurgeryOffer(code="TONSIL", waiting=70, weekly_capacity=10),
        SurgeryOffer(code="KIDNEY_STONE", waiting=55, weekly_capacity=6)
    ],
    "Jaffna Northern Care Hospital (Demo)": [
        SurgeryOffer(code="CATARACT", waiting=380, weekly_capacity=20),
        SurgeryOffer(code="HERNIA", waiting=120, weekly_capacity=8),
        SurgeryOffer(code="GALLBLADDER", waiting=150, weekly_capacity=8),
        SurgeryOffer(code="KNEE", waiting=180, weekly_capacity=4),
        SurgeryOffer(code="HIP", waiting=140, weekly_capacity=4)
    ],
    "Kurunegala Community Medical Centre (Demo)": [
        SurgeryOffer(code="CATARACT", waiting=30, weekly_capacity=18),
        SurgeryOffer(code="HERNIA", waiting=20, weekly_capacity=10),
        SurgeryOffer(code="GALLBLADDER", waiting=16, weekly_capacity=8),
        SurgeryOffer(code="KNEE", waiting=25, weekly_capacity=6),
        SurgeryOffer(code="KIDNEY_STONE", waiting=14, weekly_capacity=6)
    ],
    "Anuradhapura Heritage Hospital (Demo)": [
        SurgeryOffer(code="CATARACT", waiting=290, weekly_capacity=24),
        SurgeryOffer(code="HERNIA", waiting=110, weekly_capacity=9),
        SurgeryOffer(code="GALLBLADDER", waiting=140, weekly_capacity=9),
        SurgeryOffer(code="THYROID", waiting=38, weekly_capacity=4),
        SurgeryOffer(code="TONSIL", waiting=66, weekly_capacity=10)
    ],
    "Matara Southern Medical Centre (Demo)": [
        SurgeryOffer(code="CATARACT", waiting=240, weekly_capacity=20),
        SurgeryOffer(code="HERNIA", waiting=90, weekly_capacity=8),
        SurgeryOffer(code="GALLBLADDER", waiting=115, weekly_capacity=7),
        SurgeryOffer(code="KNEE", waiting=130, weekly_capacity=4),
        SurgeryOffer(code="HIP", waiting=105, weekly_capacity=4),
        SurgeryOffer(code="KIDNEY_STONE", waiting=48, weekly_capacity=6)
    ]
};
