// Reader-facing copy stays separate from the untouched evidence in `facts`.
// These notes use only the catalog's names, dates, styles and historic contexts.
export const editorialStories = {
  'lm-142': "A power station with Renaissance ambitions. Old Station J pairs the practical work of city infrastructure with a style associated with much grander buildings. The landmark record dates it to 1914 and credits Frederick H. Meyer. From the sidewalk, compare the building's formal appearance with the utilitarian job suggested by its name.",
  'lm-87': "Even the power supply got a formal façade. This 1907 substation is credited to Willis Polk, with a Classical Revival design. Its place in the city's reconstruction story makes it a useful stop: rebuilding San Francisco meant restoring the infrastructure behind everyday life, too.",
  'lm-108': "A brick castle for a city armory. The landmark record dates this military building to 1909 and describes its design as a mix of revival styles. Before you read it as a fortress, consider its practical role as an armory and arsenal—and how that role shaped the impression it makes on the street.",
  'lm-99': "Pipe organs are the unexpected clue in this building's name. The 1928 landmark brings instrument-making into a street usually read through its houses and shops. Its California-Spanish design adds another layer: a working building can tell you about both what a neighborhood made and how it wanted to look.",
  'lm-238': "The name gives away a different kind of temple: one connected to organized labor. Dated to 1914, this Italian Renaissance building brings together union history, social gatherings and murals in its landmark record. Think of it as part of the city's history of people meeting and organizing, as well as its architecture.",
  'lm-17': "Start with the shape. An octagonal house interrupts the usual rhythm of rectangular homes, and this one's landmark record reaches back to 1861. See how many sides you can make out from the public sidewalk; the building's footprint is the detail to notice here.",
  'lm-24': "Picture this block in the 1850s. The Yeon Building's landmark record dates it to 1855 and places it in the city's early commercial development. Its brick Italianate design offers a small point of comparison with the newer buildings around it: look at the scale and spacing of their upper-floor windows.",
  'lm-27': "This address sits at the overlap of two San Francisco stories: early commerce and reconstruction. Its landmark record gives 1906 as the date and describes a brick Italianate building. Compare it with its neighbors rather than reading the date as proof that everything you see belongs to one moment.",
  'lm-299': "Coffee is part of this building's history, not just something to pick up on the walk. The Jones-Thierbach Coffee Company name and industrial-warehouse design point to the working city behind the storefronts. The landmark record dates the building to 1907 and credits Frank S. Van Trees.",
  'lm-229': "A warehouse can be a labor-history stop. The landmark record links Garcia and Maggini's 1913 building to industry and organized labor. Its plain, utilitarian design puts the emphasis on work; compare its scale and street-level openings with the buildings beside it.",
  'lm-226': "This patch of open space has a longer timeline than many of the buildings around it. Washington Square's landmark record begins in 1849 and connects it with North Beach's Italian-American history. Pause at its edge and watch how people use the square—the public space is the landmark here.",
  'lm-254': "The sign is the landmark. The Doggie Diner record dates this piece of graphic design to 1966, credits Harold Bachman and identifies fiberglass as its material. Try reading it from farther down the sidewalk: its job was to catch an eye before anyone stopped to study it.",
  'lm-233': "The streetlights deserve a stop of their own. These 1915 light standards are connected in the landmark record to the Panama-Pacific International Exposition. Look up from the pavement and compare their design with the ordinary street furniture around them.",
  'lm-200': "Look up: the lighting is part of the street's architectural story. The Path of Gold standards are listed as Beaux Arts, with several designers and artists attached to the record. Follow their repetition along the street and notice how a small object can shape the feel of an entire route.",
  'lm-262': "This library takes a different architectural direction from the city's revival-style branches. Its landmark record dates it to 1953 and credits Appleton & Wolford with a Midcentury Modern design. Compare the entrance and window arrangement with the older civic buildings you've passed.",
  'lm-305': "A trading company's history meets the architecture of a working warehouse. The Takahashi building is recorded as a 1912 brick-and-heavy-timber structure by G. Albert Lansburgh. Its landmark context also connects it with Japantown history—a reminder to read this address through its people and businesses as well as its construction.",
  'lm-290': "A bakery building with two architectural personalities. The Royal Baking Company's 1935 landmark record names both Storybook and Art Deco styles and connects the site with Italian-American history. Study the entrance and roofline from the sidewalk, then see which parts feel playful and which feel more geometric.",
};

const field = (facts, label, next) => facts.split(label)[1]?.split(next)[0]?.trim().replace(/[.;\s]+$/, '') || '';
const contexts = [
  [/Labor|Union Halls/i, 'Work and organizing are part of this address’s story: the landmark record connects it with San Francisco’s labor history.'],
  [/Carnegie Librar|Libraries, Carnegie/i, 'A neighborhood library can be a civic landmark in its own right. This one belongs to San Francisco’s Carnegie-library history.'],
  [/Streetcar|Transit Infrastructure/i, 'Read this stop as part of a city shaped by transit. Its history is tied to the routes that connected neighborhoods.'],
  [/Water & Power/i, 'The infrastructure behind everyday life has an architectural history, too. This stop belongs to the city’s story of water and power.'],
  [/Newspapers & Publishing|Mass Media/i, 'News-making is part of this address’s history. It connects the street to the city’s newspapers and publishing world.'],
  [/Theaters|Movie Theater/i, 'This address belongs to the history of going out to the movies. Before moving on, consider how the entrance announces a place of entertainment.'],
  [/1906 Earthquake.*Reconstruction|Reconstruction.*1906 Earthquake/i, 'The 1906 earthquake and the rebuilding that followed are part of this site’s landmark history. Look at it as one piece of a city being remade.'],
  [/Manufacturing|Industrial|Shops.*Mills/i, 'This stop is a trace of the working city: making, storing and moving things is part of its landmark history.'],
  [/Burial.*Memory|Cemetaries|Columbaria/i, 'This is a stop about how the city remembers its dead. Its landmark history connects architecture with burial and memory.'],
  [/Public Education|Historic Schools/i, 'Everyday school life belongs in a city’s history, too. This landmark turns attention to the buildings that shaped generations of students.'],
  [/Finance|Bank/i, 'Read the architecture alongside its financial history. This address belongs to the city’s story of banking and commerce.'],
  [/Piers & Ports/i, 'The waterfront’s working history reaches this address. Its landmark record connects the site with the city’s piers and port.'],
  [/Early Sett[l]?l?ment|Early Settlement/i, 'This address reaches into San Francisco’s early development. Compare its scale with the newer buildings around it.'],
];

export function landmarkStory(place) {
  if (editorialStories[place.id]) return editorialStories[place.id];
  // Preserve existing narrative descriptions; only replace field-dump fallbacks.
  if (!/^The city's landmark record dates|^Architectural style:|^Architect or builder listed:|^Historic context:/.test(place.story)) return place.story;
  const facts = place.facts || place.story;
  const style = field(facts, 'Architectural style: ', 'Architect or builder listed:').split('Historic context:')[0].trim().replace(/[.;\s]+$/, '');
  const context = field(facts, 'Historic context: ', '\u0000');
  const year = place.year > 1700 ? place.year : null;
  // Complicated attribution fields (remodels, builders, restorations) remain in
  // source evidence instead of being flattened into an incorrect design credit.
  let opening = contexts.find(([pattern]) => pattern.test(context))?.[1];
  if (!opening && /House|Residence|Cottage|Apartments|Flats/i.test(place.name)) opening = 'Look at the entrance, then the upper floors. A home’s place in the streetscape is easier to notice when you compare it with the houses next door.';
  if (!opening && /Church|Temple|Cathedral|Synag/i.test(place.name)) opening = 'Consider how this building marks a place of worship on an ordinary city street. Compare its entrance and silhouette with the surrounding buildings.';
  if (!opening) opening = `Pause at ${place.name} and compare it with the surrounding street. The contrast in scale, shape or purpose is a starting point for reading this landmark.`;
  const cleanStyle = style && !/[?]|NR characterization|Altered|vernacular|;|\//i.test(style) ? style.replace(/^"|"$/g, '') : '';
  const anchor = year && cleanStyle ? `The landmark record dates it to ${year} and describes its design as ${cleanStyle}.` : year ? `The landmark record dates the site to ${year}.` : cleanStyle ? `Its ${cleanStyle} design is the architectural thread to follow here.` : '';
  return [opening, anchor].filter(Boolean).join(' ');
}
