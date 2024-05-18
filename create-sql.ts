const base = `
SELECT
  *
FROM
  public.users_notification_settings
  INNER JOIN (
    SELECT
      DISTINCT ON (id)
      id
    FROM
      public.users_earthquake_settings
    WHERE
      (region_id, min_jma_intensity) IN (
`;

const close = `)
  ) AS subquery ON public.users_notification_settings.id = subquery.id;`;

const jma_intensity_choices = [
  "0",
  "1",
  "2",
  "3",
  "4",
  "5-",
  "5+",
  "6-",
  "6+",
  "7",
];

const values: [number, string][] = [];

for (let i = 1; i <= 47; i++) {
  if (Math.random() < 0.5) continue;
  const jma_intensity = jma_intensity_choices[
    Math.floor(Math.random() * jma_intensity_choices.length)
  ];
  for (let j = 0; j < jma_intensity_choices.indexOf(jma_intensity); j++) {
    values.push([i, jma_intensity_choices[j]]);
  }
}

const sql = base + values.map((e) => `(${e[0]}, '${e[1]}')`).join(", ") + close;
console.log(sql);
