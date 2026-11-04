export const googleFonts = [
  { family: 'Manrope', id: 'manrope' },
  {
    "family": "Inter",
    "id": "inter"
  },
  {
    "family": "Roboto",
    "id": "roboto"
  },
  {
    "family": "Open Sans",
    "id": "opensans"
  },
  {
    "family": "Lato",
    "id": "lato"
  },
  {
    "family": "Montserrat",
    "id": "montserrat"
  },
  {
    "family": "Nunito",
    "id": "nunito"
  },
  {
    "family": "Source Sans 3",
    "id": "sourcesans3"
  },
  {
    "family": "Merriweather",
    "id": "merriweather"
  },
  {
    "family": "Public Sans",
    "id": "publicsans"
  },
  {
    "family": "Lora",
    "id": "lora"
  }
] as const

export function fontStack(family: string | null | undefined): string {
 const known=googleFonts.some(f=>f.family===family)
 return `${JSON.stringify(known?family:'Inter')}, 'Inter', sans-serif`
}
