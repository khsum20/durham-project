import pandas as pd
import matplotlib.pyplot as plt

# ============================================================
# 1. Load data
# ============================================================
# Semicolon-delimited, not comma — without sep=";" pandas reads
# the whole line as one column.
data_set = pd.read_csv("vehicle-registration.csv", sep=";")
data_set["Date"] = pd.to_datetime(data_set["Date"])

# ============================================================
# 2. Estimated CO2 emissions per vehicle per year (metric tons)
# ASSUMPTIONS, not measurements — this dataset has only vehicle
# counts, no mileage or fuel-consumption data. Adjust freely.
# ============================================================
EMISSION_FACTORS = {
    "Gas": 4.6,              # EPA average for a typical gasoline vehicle (~11,500 mi/yr @ ~22 mpg)
    "Diesel": 5.1,           # illustrative: diesel carries ~15% more CO2/gallon than gasoline
    "Hybrid": 2.3,           # rough "~50% of a gas vehicle" approximation
    "Plug-In Hybrid*": 1.4,  # rough "~70% reduction" approximation
    "Electric": 0.0,         # placeholder, replaced below with a grid-based estimate
}

# Electric: grid-based ("well-to-wheel") instead of zero tailpipe
GRID_FACTOR_LB_PER_MWH = 593          # your local grid's carbon intensity
EV_EFFICIENCY_KWH_PER_MILE = 0.30     # typical EV, ~0.25-0.40 depending on model
AVG_ANNUAL_MILES = 11500              # same mileage assumption used for the gas factor

grid_factor_t_per_mwh = GRID_FACTOR_LB_PER_MWH / 2204.62      # lb/MWh -> metric tons/MWh
annual_mwh_per_ev = (AVG_ANNUAL_MILES * EV_EFFICIENCY_KWH_PER_MILE) / 1000
EMISSION_FACTORS["Electric"] = grid_factor_t_per_mwh * annual_mwh_per_ev

print(f"Grid factor:               {grid_factor_t_per_mwh:.4f} metric tons CO2/MWh")
print(f"Estimated EV consumption:  {annual_mwh_per_ev:.3f} MWh/year")
print(f"=> Estimated EV emissions: {EMISSION_FACTORS['Electric']:.3f} metric tons CO2/year")
print()

# ============================================================
# 3. Durham County, per-year snapshot (NOT summed — these columns
# are running totals, not monthly new registrations)
# ============================================================
fuel_cols = ["Electric", "Plug-In Hybrid*", "Hybrid", "Gas", "Diesel"]

durham = data_set[data_set["Area Name"] == "Durham County"].copy()
durham = durham.sort_values("Date")
durham_yearly = durham.groupby("Year")[fuel_cols].last()

# ============================================================
# 4. Vehicle count x emissions factor, per type, per year
# ============================================================
emissions = durham_yearly.copy()
for col in fuel_cols:
    emissions[col] = durham_yearly[col] * EMISSION_FACTORS[col]
emissions["Total"] = emissions[fuel_cols].sum(axis=1)

print("Estimated CO2 emissions in Durham County, metric tons/year:")
print(emissions.round(0))
print()

# ============================================================
# 5. Chart: share of total emissions by fuel type, per year
# (100%-stacked area — plain stacking would bury the small series
# under Gas, which is ~150x larger; normalizing to % fixes that)
# ============================================================
shares = emissions[fuel_cols].div(emissions[fuel_cols].sum(axis=1), axis=0) * 100
colors = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4"]  # fixed order, one per type

fig, ax = plt.subplots(figsize=(9, 5.5))
fig.patch.set_facecolor("#fcfcfb")
ax.set_facecolor("#fcfcfb")

ax.stackplot(shares.index, [shares[c] for c in fuel_cols], colors=colors, labels=fuel_cols)

ax.set_ylim(0, 100)
ax.set_ylabel("Share of estimated emissions (%)", color="#52514e")
ax.set_xlabel("Year", color="#52514e")
ax.set_title("Durham County: emissions mix by fuel type", fontsize=13, color="#0b0b0b")
ax.grid(axis="y", color="#e1e0d9", linewidth=0.8)
ax.spines[["top", "right"]].set_visible(False)
ax.spines[["left", "bottom"]].set_color("#c3c2b7")
ax.tick_params(colors="#898781", labelsize=9)
ax.legend(frameon=False, labelcolor="#52514e", loc="upper left", bbox_to_anchor=(1.0, 1.0))

plt.tight_layout()
plt.show()
