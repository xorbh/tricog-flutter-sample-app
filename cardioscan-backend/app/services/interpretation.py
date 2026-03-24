"""Python port of the Flutter InterpretationService."""

import asyncio
from dataclasses import dataclass, field

SAMPLE_RATE = 250


@dataclass
class InterpretationResult:
    diagnosis: str
    severity: str
    heart_rate: int
    details: str
    findings: list[str] = field(default_factory=list)


def _estimate_heart_rate(ecg_data: list[float]) -> int:
    if len(ecg_data) < 10:
        return 72
    max_val = max(ecg_data)
    threshold = max_val * 0.6
    r_peaks: list[int] = []
    for i in range(1, len(ecg_data) - 1):
        if (
            ecg_data[i] > threshold
            and ecg_data[i] > ecg_data[i - 1]
            and ecg_data[i] > ecg_data[i + 1]
        ):
            if not r_peaks or i - r_peaks[-1] > SAMPLE_RATE * 0.3:
                r_peaks.append(i)
    if len(r_peaks) < 2:
        return 72
    avg_interval = (r_peaks[-1] - r_peaks[0]) / (len(r_peaks) - 1)
    return round(60.0 * SAMPLE_RATE / avg_interval)


async def analyze(ecg_data: list[float], ecg_type: str) -> InterpretationResult:
    """Analyze ECG data and return interpretation. Simulates API latency."""
    await asyncio.sleep(0.5)
    hr = _estimate_heart_rate(ecg_data)

    match ecg_type:
        case "normal":
            return InterpretationResult(
                diagnosis="Normal Sinus Rhythm",
                severity="normal",
                heart_rate=hr,
                details="The ECG shows a normal sinus rhythm with regular rate and rhythm.",
                findings=[
                    "Regular R-R intervals",
                    "Normal P wave morphology",
                    "Normal PR interval (120-200ms)",
                    "Narrow QRS complex (<120ms)",
                    "Normal ST segment",
                    "Normal T wave morphology",
                ],
            )
        case "tachycardia":
            return InterpretationResult(
                diagnosis="Sinus Tachycardia",
                severity="warning",
                heart_rate=hr,
                details="Heart rate is elevated above 100 BPM. Sinus P waves present before each QRS.",
                findings=[
                    "Elevated heart rate (>100 BPM)",
                    "Regular R-R intervals",
                    "Normal P wave before each QRS",
                    "Narrow QRS complex",
                    "Consider causes: fever, anxiety, dehydration, anemia",
                ],
            )
        case "bradycardia":
            return InterpretationResult(
                diagnosis="Sinus Bradycardia",
                severity="warning",
                heart_rate=hr,
                details="Heart rate is below 60 BPM. Rhythm is regular with normal P waves.",
                findings=[
                    "Low heart rate (<60 BPM)",
                    "Regular R-R intervals",
                    "Normal P wave morphology",
                    "Normal PR interval",
                    "May be normal in athletes or during sleep",
                ],
            )
        case "afib":
            return InterpretationResult(
                diagnosis="Atrial Fibrillation",
                severity="critical",
                heart_rate=hr,
                details="Irregularly irregular rhythm with absence of organized P waves.",
                findings=[
                    "Irregularly irregular R-R intervals",
                    "Absence of distinct P waves",
                    "Fibrillatory baseline",
                    "Variable ventricular rate",
                    "URGENT: Assess stroke risk (CHA2DS2-VASc)",
                    "Consider anticoagulation therapy",
                ],
            )
        case "st_elevation":
            return InterpretationResult(
                diagnosis="ST Segment Elevation",
                severity="critical",
                heart_rate=hr,
                details="Significant ST elevation detected. May indicate acute myocardial infarction.",
                findings=[
                    "ST segment elevation >1mm",
                    "Possible acute myocardial injury",
                    "URGENT: Rule out STEMI",
                    "Immediate cardiology consultation recommended",
                    "Consider emergent catheterization",
                ],
            )
        case "pvc":
            return InterpretationResult(
                diagnosis="Premature Ventricular Contractions",
                severity="warning",
                heart_rate=hr,
                details="Premature wide QRS complexes observed without preceding P waves.",
                findings=[
                    "Premature wide QRS complexes",
                    "No preceding P wave for PVC beats",
                    "Compensatory pause after PVCs",
                    "Underlying rhythm appears sinus",
                    "Monitor for frequency and symptoms",
                ],
            )
        case _:
            return InterpretationResult(
                diagnosis="Unclassified",
                severity="warning",
                heart_rate=hr,
                details="Unable to classify this ECG pattern.",
                findings=["Further review recommended"],
            )
