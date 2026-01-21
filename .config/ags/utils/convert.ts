export interface ConversionResult {
  value: number;
  unit: string;
  formatted: string;
  original: string;
}

export interface UnitDefinition {
  name: string;
  type: "temperature" | "weight" | "length" | "volume" | "speed" | "digital";
  baseUnit: string;
  conversions: Record<string, (value: number) => number>;
}

// Temperature conversion functions
const celsiusToFahrenheit = (c: number): number => (c * 9) / 5 + 32;
const fahrenheitToCelsius = (f: number): number => ((f - 32) * 5) / 9;
const celsiusToKelvin = (c: number): number => c + 273.15;
const kelvinToCelsius = (k: number): number => k - 273.15;

// Unit definitions
export const unitDefinitions: Record<string, UnitDefinition> = {
  // Temperature
  celsius: {
    name: "Celsius",
    type: "temperature",
    baseUnit: "celsius",
    conversions: {
      fahrenheit: celsiusToFahrenheit,
      kelvin: celsiusToKelvin,
    },
  },
  fahrenheit: {
    name: "Fahrenheit",
    type: "temperature",
    baseUnit: "celsius",
    conversions: {
      celsius: fahrenheitToCelsius,
      kelvin: (f: number) => celsiusToKelvin(fahrenheitToCelsius(f)),
    },
  },
  kelvin: {
    name: "Kelvin",
    type: "temperature",
    baseUnit: "celsius",
    conversions: {
      celsius: kelvinToCelsius,
      fahrenheit: (k: number) => celsiusToFahrenheit(kelvinToCelsius(k)),
    },
  },

  // Weight/Mass
  kg: {
    name: "Kilograms",
    type: "weight",
    baseUnit: "kg",
    conversions: {
      g: (kg: number) => kg * 1000,
      lb: (kg: number) => kg * 2.20462,
      oz: (kg: number) => kg * 35.274,
      ton: (kg: number) => kg / 1000,
    },
  },
  g: {
    name: "Grams",
    type: "weight",
    baseUnit: "kg",
    conversions: {
      kg: (g: number) => g / 1000,
      lb: (g: number) => g * 0.00220462,
      oz: (g: number) => g * 0.035274,
    },
  },
  lb: {
    name: "Pounds",
    type: "weight",
    baseUnit: "kg",
    conversions: {
      kg: (lb: number) => lb * 0.453592,
      g: (lb: number) => lb * 453.592,
      oz: (lb: number) => lb * 16,
    },
  },
  oz: {
    name: "Ounces",
    type: "weight",
    baseUnit: "kg",
    conversions: {
      kg: (oz: number) => oz * 0.0283495,
      g: (oz: number) => oz * 28.3495,
      lb: (oz: number) => oz * 0.0625,
    },
  },

  // Length/Distance
  m: {
    name: "Meters",
    type: "length",
    baseUnit: "m",
    conversions: {
      km: (m: number) => m / 1000,
      cm: (m: number) => m * 100,
      mm: (m: number) => m * 1000,
      mi: (m: number) => m * 0.000621371,
      ft: (m: number) => m * 3.28084,
      in: (m: number) => m * 39.3701,
    },
  },
  km: {
    name: "Kilometers",
    type: "length",
    baseUnit: "m",
    conversions: {
      m: (km: number) => km * 1000,
      mi: (km: number) => km * 0.621371,
      ft: (km: number) => km * 3280.84,
    },
  },
  mi: {
    name: "Miles",
    type: "length",
    baseUnit: "m",
    conversions: {
      m: (mi: number) => mi * 1609.34,
      km: (mi: number) => mi * 1.60934,
      ft: (mi: number) => mi * 5280,
    },
  },
  ft: {
    name: "Feet",
    type: "length",
    baseUnit: "m",
    conversions: {
      m: (ft: number) => ft * 0.3048,
      cm: (ft: number) => ft * 30.48,
      in: (ft: number) => ft * 12,
    },
  },
  in: {
    name: "Inches",
    type: "length",
    baseUnit: "m",
    conversions: {
      m: (inch: number) => inch * 0.0254,
      cm: (inch: number) => inch * 2.54,
      ft: (inch: number) => inch / 12,
    },
  },

  // Volume
  l: {
    name: "Liters",
    type: "volume",
    baseUnit: "l",
    conversions: {
      ml: (l: number) => l * 1000,
      gal: (l: number) => l * 0.264172,
      cup: (l: number) => l * 4.22675,
      "fl oz": (l: number) => l * 33.814,
    },
  },
  ml: {
    name: "Milliliters",
    type: "volume",
    baseUnit: "l",
    conversions: {
      l: (ml: number) => ml / 1000,
      cup: (ml: number) => ml * 0.00422675,
      tsp: (ml: number) => ml * 0.202884,
    },
  },
  gal: {
    name: "Gallons",
    type: "volume",
    baseUnit: "l",
    conversions: {
      l: (gal: number) => gal * 3.78541,
      ml: (gal: number) => gal * 3785.41,
      qt: (gal: number) => gal * 4,
    },
  },

  // Digital Storage
  gb: {
    name: "Gigabytes",
    type: "digital",
    baseUnit: "byte",
    conversions: {
      mb: (gb: number) => gb * 1024,
      kb: (gb: number) => gb * 1024 * 1024,
      tb: (gb: number) => gb / 1024,
      pb: (gb: number) => gb / (1024 * 1024),
    },
  },
  mb: {
    name: "Megabytes",
    type: "digital",
    baseUnit: "byte",
    conversions: {
      gb: (mb: number) => mb / 1024,
      kb: (mb: number) => mb * 1024,
      tb: (mb: number) => mb / (1024 * 1024),
    },
  },

  // Speed
  "km/h": {
    name: "Kilometers per hour",
    type: "speed",
    baseUnit: "m/s",
    conversions: {
      "m/s": (kmh: number) => kmh / 3.6,
      mph: (kmh: number) => kmh * 0.621371,
      knot: (kmh: number) => kmh * 0.539957,
    },
  },
  mph: {
    name: "Miles per hour",
    type: "speed",
    baseUnit: "m/s",
    conversions: {
      "km/h": (mph: number) => mph * 1.60934,
      "m/s": (mph: number) => mph * 0.44704,
      knot: (mph: number) => mph * 0.868976,
    },
  },
};

// Parse input string to extract value and units
export function parseConversionInput(input: string): {
  value: number;
  fromUnit: string;
  toUnit: string | null;
  original: string;
} | null {
  // Patterns to match:
  // 1. "100c to f" or "100c in f"
  // 2. "100 celsius to fahrenheit"
  // 3. "convert 100c to f"
  // 4. "100 kg in lb"

  const patterns = [
    /^(\d+(?:\.\d+)?)\s*([a-zA-Z°/%]+(?:\s+[a-zA-Z]+)?)(?:\s+(?:to|in|as|=>)\s+([a-zA-Z°/%]+(?:\s+[a-zA-Z]+)?))?$/i,
    /^convert\s+(\d+(?:\.\d+)?)\s*([a-zA-Z°/%]+(?:\s+[a-zA-Z]+)?)(?:\s+(?:to|in|as|=>)\s+([a-zA-Z°/%]+(?:\s+[a-zA-Z]+)?))?$/i,
  ];

  for (const pattern of patterns) {
    const match = input.match(pattern);
    if (match) {
      const value = parseFloat(match[1]);
      const fromUnit = normalizeUnit(match[2].trim().toLowerCase());
      const toUnit = match[3]
        ? normalizeUnit(match[3].trim().toLowerCase())
        : null;

      return { value, fromUnit, toUnit, original: input };
    }
  }

  return null;
}

// Normalize unit strings
function normalizeUnit(unit: string): string {
  const unitMap: Record<string, string> = {
    // Temperature
    c: "celsius",
    "°c": "celsius",
    celcius: "celsius",
    f: "fahrenheit",
    "°f": "fahrenheit",
    fahr: "fahrenheit",
    k: "kelvin",
    "°k": "kelvin",

    // Weight
    kilogram: "kg",
    kilograms: "kg",
    kilo: "kg",
    kilos: "kg",
    gram: "g",
    grams: "g",
    pound: "lb",
    pounds: "lb",
    lbs: "lb",
    ounce: "oz",
    ounces: "oz",
    tonne: "ton",
    tonnes: "ton",
    tons: "ton",

    // Length
    meter: "m",
    meters: "m",
    metre: "m",
    metres: "m",
    centimeter: "cm",
    centimeters: "cm",
    centimetre: "cm",
    centimetres: "cm",
    millimeter: "mm",
    millimeters: "mm",
    millimetre: "mm",
    millimetres: "mm",
    kilometer: "km",
    kilometers: "km",
    kilometre: "km",
    kilometres: "km",
    mile: "mi",
    miles: "mi",
    foot: "ft",
    feet: "ft",
    inch: "in",
    inches: "in",
    yard: "yd",
    yards: "yd",

    // Volume
    liter: "l",
    liters: "l",
    litre: "l",
    litres: "l",
    milliliter: "ml",
    milliliters: "ml",
    millilitre: "ml",
    millilitres: "ml",
    gallon: "gal",
    gallons: "gal",
    quart: "qt",
    quarts: "qt",
    pint: "pt",
    pints: "pt",
    cup: "cup",
    cups: "cup",
    tablespoon: "tbsp",
    tablespoons: "tbsp",
    tbsp: "tbsp",
    teaspoon: "tsp",
    teaspoons: "tsp",
    tsp: "tsp",
    "fluid ounce": "fl oz",
    "fluid ounces": "fl oz",

    // Digital
    byte: "b",
    bytes: "b",
    kilobyte: "kb",
    kilobytes: "kb",
    kib: "kb",
    megabyte: "mb",
    megabytes: "mb",
    mib: "mb",
    gigabyte: "gb",
    gigabytes: "gb",
    gib: "gb",
    terabyte: "tb",
    terabytes: "tb",
    tib: "tb",
    petabyte: "pb",
    petabytes: "pb",
    pib: "pb",

    // Speed
    kph: "km/h",
    kmph: "km/h",
    "km per hour": "km/h",
    mps: "m/s",
    "meters per second": "m/s",
    mph: "mph",
    "miles per hour": "mph",
    knots: "knot",
    kts: "knot",
  };

  // Check if unit exists in map
  const normalized = unitMap[unit] || unit;

  return normalized;
}

// Perform conversion
export async function convert(input: string): Promise<ConversionResult[]> {
  const parsed = parseConversionInput(input);
  if (!parsed) {
    throw new Error(
      'Invalid conversion format. Try: "100c to f" or "10kg in lb"',
    );
  }

  const { value, fromUnit, toUnit, original } = parsed;

  // Handle regular unit conversion
  const fromDef = unitDefinitions[fromUnit];
  if (!fromDef) {
    throw new Error(`Unknown unit: ${fromUnit}`);
  }

  const results: ConversionResult[] = [];

  if (toUnit) {
    // Convert to specific unit
    const toDef = unitDefinitions[toUnit];
    if (!toDef || fromDef.type !== toDef.type) {
      throw new Error(`Cannot convert ${fromDef.type} to ${toUnit}`);
    }

    const convertedValue = fromDef.conversions[toUnit](value);
    results.push({
      value: convertedValue,
      unit: toUnit,
      formatted: formatNumber(convertedValue) + " " + toUnit,
      original: `${value} ${fromUnit}`,
    });
  } else {
    // Show all common conversions for this unit type
    const targetUnits = getCommonConversionsForType(fromDef.type, fromUnit);

    for (const targetUnit of targetUnits) {
      const convertedValue = fromDef.conversions[targetUnit](value);
      results.push({
        value: convertedValue,
        unit: targetUnit,
        formatted: formatNumber(convertedValue) + " " + targetUnit,
        original: `${value} ${fromUnit}`,
      });
    }
  }

  return results;
}

// Get common conversions for a unit type
function getCommonConversionsForType(
  type: string,
  excludeUnit: string,
): string[] {
  const commonConversions: Record<string, string[]> = {
    temperature: ["celsius", "fahrenheit", "kelvin"],
    weight: ["kg", "g", "lb", "oz"],
    length: ["m", "cm", "mm", "km", "mi", "ft", "in"],
    volume: ["l", "ml", "gal", "cup"],
    digital: ["b", "kb", "mb", "gb", "tb"],
    speed: ["km/h", "mph", "m/s", "knot"],
  };

  return (commonConversions[type] || []).filter((unit) => unit !== excludeUnit);
}

// Format numbers nicely
function formatNumber(num: number): string {
  if (Math.abs(num) < 0.01 || Math.abs(num) >= 1000000) {
    return num.toExponential(4);
  }
  if (Math.abs(num) < 1) {
    return num.toFixed(4).replace(/\.?0+$/, "");
  }
  if (Math.abs(num) < 10) {
    return num.toFixed(3).replace(/\.?0+$/, "");
  }
  if (Math.abs(num) < 1000) {
    return num.toFixed(2).replace(/\.?0+$/, "");
  }
  return num.toFixed(1).replace(/\.0$/, "");
}

// Check if input is a conversion query
export function isConversionQuery(text: string): boolean {
  return (
    /^(convert\s+)?\d+(\.\d+)?\s*[a-zA-Z°%]/.test(text) ||
    /\d+(\.\d+)?\s*[a-zA-Z°%]+\s+(to|in|as|=>)\s+[a-zA-Z°%]+/.test(text)
  );
}
