# Guide: Fixa Runrikets undermenyer så de fungerar offline

Den här guiden förklarar **vad problemet var**, **hur jag hittade det**, och **exakt vad jag ändrade i vilka filer** – så att du kan göra samma sak manuellt på en annan kopia av Runriket.

---

## 1. Symptomet

I menyn (sidomenyn som fälls ut) finns två punkter med ett plus-tecken (＋):

- **Runrikets platser**
- **I fokus**

Online fälls undermenyn ut när man klickar på ＋. **Offline hände ingenting** – undermenyn var tom.

---

## 2. Orsaken

Undermenyerna finns inte i HTML:en från början. De **hämtas från servern** med JavaScript när man klickar på ＋.

Koden finns i den minifierade filen:

```
www.vallentuna.se/static/app.bundle.js@v=0276ba16d7aefa7bf349b3568a3a15a8
```

Den relevanta logiken (uttolkad ur den minifierade koden):

```javascript
// Körs när man klickar på en expander-knapp (＋)
expandCollapseMenuItem(klick) {
    var knapp = ...;                         // själva ＋-knappen
    var li    = knapp.parentElement.parentElement;  // <li>-elementet i menyn
    var ul    = li.querySelector("ul");      // finns en undermeny redan?

    if (!ul || ul.classList.contains("hidden")) {
        // Fäll ut:
        if (ul) {
            ul.classList.remove("hidden");   // (A) visa befintlig lista
        } else {
            // (B) INGEN lista finns -> hämta från servern:
            this.loadNavigationFragment(knapp.dataset.id, knapp.dataset.level, ...);
        }
    } else {
        ul.classList.add("hidden");          // Fäll ihop
    }
}

loadNavigationFragment(id, level, callback) {
    fetch("/navigation/loadnavigationfragment/?id=" + id + "&level=" + level, {
        method: "GET", credentials: "include"
    })
    .then(svar => svar.text())
    .then(html => callback(html));           // lägger in resultatet i menyn
}
```

**Det kritiska:** `fetch("/navigation/loadnavigationfragment/...")` kräver en levande server.
Offline (och på en annan domän) finns ingen sådan → anropet misslyckas → menyn förblir tom.

> Extra ledtråd: om man testar den gamla adressen idag får man **404** – kommunens sajt är dessutom ombyggd sedan arkiveringen, så endpointen finns inte ens kvar.

---

## 3. Lösningens idé (ingen JavaScript behöver ändras)

Titta på koden ovan igen. JavaScripten gör serveranropet **endast i gren (B)** – alltså bara när det *inte redan finns* en `<ul>` i menypunkten.

Om vi **lägger in undermenyn som färdig HTML** (men dold med `class="hidden"`), så:

- hamnar vi alltid i gren (A) → `ul.classList.remove("hidden")` → listan visas
- `fetch(...)` körs **aldrig**

Klassen `hidden` finns redan i CSS:en (`.hidden{display:none}`), så en `<ul class="... hidden">` är osynlig tills man klickar.

**Resultat:** menyn fungerar helt lokalt, och vi rör inte en enda rad JavaScript.

---

## 4. Exakt vad som ändrades

Alla ändringar gjordes i `index.html`-filerna under:

```
www.vallentuna.se/runriket/
```

### 4.1 Hitta rätt ställe i filen

I varje sida finns sidomenyn (`<ul class="nav-tree nav-tree--level-0">`). Där ligger menypunkterna. De två med undermeny ser ut så här (ihopfällt läge):

**Runrikets platser** (id = `43434`):
```html
<li><div class="nav-tree__item"><a href="...runrikets-platser/index.html">Runrikets platser</a>
<button class="nav-tree__expander" data-id="43434" data-level="1"><span class="visually-hidden">Expandera meny</span><i class="material-icons" aria-hidden="true">add_circle_outline</i></button></div></li>
```

**I fokus** (id = `43450`):
```html
<li><div class="nav-tree__item"><a href="...i-fokus/index.html">I fokus</a>
<button class="nav-tree__expander" data-id="43450" data-level="1">...</button></div></li>
```

### 4.2 Vad som lades in

Direkt **efter `</button></div>`** och **före `</li>`** la jag in en dold `<ul>`.

**För "Runrikets platser"** (10 platser, inklusive kartan). Exempel för en sida som ligger **en mapp ner** under `runriket/` (prefix `../`):

```html
<ul class="nav-tree nav-tree--level-1 hidden"><li><div class="nav-tree__item"><a href="../runrikets-platser/karta-over-runriket/index.html">Karta över Runriket</a></div></li><li><div class="nav-tree__item"><a href="../runrikets-platser/jarlabankes-bro/index.html">Jarlabankes bro</a></div></li><li><div class="nav-tree__item"><a href="../runrikets-platser/broby-bro/index.html">Broby bro</a></div></li><li><div class="nav-tree__item"><a href="../runrikets-platser/taby-kyrka/index.html">Täby kyrka</a></div></li><li><div class="nav-tree__item"><a href="../runrikets-platser/fallbro/index.html">Fällbro</a></div></li><li><div class="nav-tree__item"><a href="../runrikets-platser/risbyle/index.html">Risbyle</a></div></li><li><div class="nav-tree__item"><a href="../runrikets-platser/gallsta/index.html">Gällsta</a></div></li><li><div class="nav-tree__item"><a href="../runrikets-platser/gullbron/index.html">Gullbron</a></div></li><li><div class="nav-tree__item"><a href="../runrikets-platser/vallentuna-kyrka/index.html">Vallentuna kyrka</a></div></li><li><div class="nav-tree__item"><a href="../runrikets-platser/arkils-tingstad/index.html">Arkils tingstad</a></div></li></ul>
```

**För "I fokus"** (bara en punkt). Exempel med prefix `../`:

```html
<ul class="nav-tree nav-tree--level-1 hidden"><li><div class="nav-tree__item"><a href="../i-fokus/i-was-here---dansrunor/index.html">I was here - Dansrunor</a></div></li></ul>
```

### 4.3 ⚠️ Antalet `../` beror på hur djupt sidan ligger

Länkarna är **relativa**, så prefixet måste matcha sidans djup under `runriket/`:

| Sidans plats | Djup | Prefix |
|---|---|---|
| `runriket/index.html` (startsidan) | 0 | *(inget)* → `runrikets-platser/...` |
| `runriket/om-runriket/index.html` (och övriga på denna nivå) | 1 | `../` |
| `runriket/runrikets-platser/arkils-tingstad/index.html` (platssidorna) | 2 | `../../` |
| `runriket/i-fokus/i-was-here---dansrunor/index.html` | 2 | `../../` |

Regel: **djup = antal mappar ner från `runriket/`**, och prefix = så många `../`.

### 4.4 Vilka sidor fick vad

Vissa sidor hade redan undermenyn utfälld statiskt (där servern råkade rendera den vid arkiveringen). Dem rörde jag inte. Så här blev det (22 sidor totalt):

| Sida | Djup | "Platser" | "I fokus" |
|---|---|---|---|
| `index.html` | 0 | lades in | lades in |
| `om-runriket/index.html` | 1 | lades in | lades in |
| `runrikets-vikingahelg/index.html` | 1 | lades in | lades in |
| `hitta-i-runriket/index.html` | 1 | lades in | lades in |
| `vikingakvinnan-estrid/index.html` | 1 | lades in | lades in |
| `barnens-runrike/index.html` | 1 | lades in | lades in |
| `boka-din-guide/index.html` | 1 | lades in | lades in |
| `in-english/index.html` | 1 | lades in | lades in |
| `om-webbplatsen/index.html` | 1 | lades in | lades in |
| `i-fokus/index.html` | 1 | lades in | *fanns redan* |
| `i-fokus/i-was-here---dansrunor/index.html` | 2 | lades in | *fanns redan* |
| `runrikets-platser/index.html` | 1 | *fanns redan* | lades in |
| `runrikets-platser/karta-over-runriket/index.html` | 2 | *fanns redan* | lades in |
| `runrikets-platser/jarlabankes-bro/index.html` | 2 | *fanns redan* | lades in |
| `runrikets-platser/broby-bro/index.html` | 2 | *fanns redan* | lades in |
| `runrikets-platser/taby-kyrka/index.html` | 2 | *fanns redan* | lades in |
| `runrikets-platser/fallbro/index.html` | 2 | *fanns redan* | lades in |
| `runrikets-platser/risbyle/index.html` | 2 | *fanns redan* | lades in |
| `runrikets-platser/gallsta/index.html` | 2 | *fanns redan* | lades in |
| `runrikets-platser/gullbron/index.html` | 2 | *fanns redan* | lades in |
| `runrikets-platser/vallentuna-kyrka/index.html` | 2 | *fanns redan* | lades in |
| `runrikets-platser/arkils-tingstad/index.html` | 2 | *fanns redan* | lades in |

Totalt: "Platser" lades in på **11** sidor, "I fokus" på **20** sidor.

---

## 5. Gör det manuellt – steg för steg

### Alternativ A (rekommenderas): kör skriptet
I arkivet finns `fixa-meny.ps1` som gör allt automatiskt (räknar ut rätt `../` och hoppar över redan fixade sidor). Kräver ingen installation:

1. Lägg `fixa-meny.ps1` i arkivets rot (där `index.html` ligger).
2. Shift + högerklick i mappen → **Öppna PowerShell-fönster här**.
3. Kör:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\fixa-meny.ps1
   ```

### Alternativ B: handredigera (om du vill göra det själv)
Gör så här för **varje** `index.html` under `www.vallentuna.se/runriket/`:

1. Öppna filen i en textredigerare (t.ex. Anteckningar/Notepad eller VS Code).
2. Sök (Ctrl+F) efter: `data-id="43434"`
3. Precis efter den knappens `</button></div>` (och före `</li>`): klistra in **Platser-`<ul>`:en** från avsnitt 4.2.
   - **Hoppa över** om det redan står `<ul ...nav-tree--level-1...>` direkt efter – då finns listan redan.
4. Sök efter: `data-id="43450"`
5. Gör samma sak där med **I fokus-`<ul>`:en**.
6. **Justera alla `../`** enligt tabellen i avsnitt 4.3 utifrån hur djupt sidan ligger.
7. Spara filen (som UTF-8).

### Så testar du
Starta en lokal server (eller öppna `index.html`), öppna menyn och klicka på ＋ vid "Runrikets platser" och "I fokus". Listorna ska nu fällas ut utan internet.

---

## 6. Varför det är säkert

- Vi ändrar **ingen JavaScript** – bara lägger till HTML som webbläsaren redan vet hur den ska visa.
- `class="hidden"` gör att listan är dold tills man klickar (samma beteende som original).
- Länkarna är relativa → fungerar både lokalt (via file:// eller lokal server) och på en annan domän/GitHub Pages.
- Att köra `fixa-meny.ps1` flera gånger är ofarligt – det hoppar över sidor som redan är fixade.
