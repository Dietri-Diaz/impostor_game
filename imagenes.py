"""
Descargador de imágenes para impostor_game.

A diferencia del intento anterior con icrawler/Bing (que devolvía cualquier cosa),
este script usa APIs oficiales por tipo de contenido:

  • PokeAPI        → personajes de Pokémon (PNG transparente oficial)
  • Jikan API      → personajes de anime (DBZ, Naruto, One Piece, Demon Slayer, AoT)
  • Wikipedia API  → todo lo demás (Marvel, DC, series live action, Disney, Mario)

No requiere ninguna API key ni signup. Solo HTTP público.

Uso:
    python imagenes.py
"""

import json
import os
import shutil
import time
import urllib.parse
import urllib.request

USER_AGENT = "impostor-game-image-fetcher/1.0 (personal use)"
TIMEOUT = 15

# ─── DATA: qué buscar por tema ────────────────────────────────────────────────
# Por tema definimos:
#   - source: "pokeapi" | "jikan" | "wikipedia"
#   - logo_query: para la imagen de portada del tema
#   - personajes: { archivo_destino: query_para_la_API }
#
# Para PokeAPI la query es el nombre en inglés en minúsculas.
# Para Jikan la query es el nombre del personaje (top result por popularidad).
# Para Wikipedia es lo que se va a buscar (Wikipedia search devuelve el artículo
# más relevante automáticamente).

TEMAS = {
    "pokemon": {
        "source": "pokeapi",
        "logo": ("wikipedia", "Pokémon logo"),  # PokeAPI no tiene logo, usamos Wikipedia
        "personajes": {
            "pikachu":   "pikachu",
            "charizard": "charizard",
            "bulbasaur": "bulbasaur",
            "squirtle":  "squirtle",
            "mewtwo":    "mewtwo",
            "mew":       "mew",
            "eevee":     "eevee",
            "snorlax":   "snorlax",
            "gengar":    "gengar",
            "gyarados":  "gyarados",
            "dragonite": "dragonite",
            "lucario":   "lucario",
            "greninja":  "greninja",
            "arceus":    "arceus",
        },
    },
    "dragon_ball": {
        "source": "jikan",
        "jikan_anime": [
            "Dragon Ball Z",
            "Dragon Ball",
            "Dragon Ball Super",
            "Dragon Ball Super: Broly",
        ],
        "logo": ("wikipedia", "Dragon Ball (franchise)"),
        "personajes": {
            "goku":       "Son Goku",
            "vegeta":     "Vegeta",
            "piccolo":    "Piccolo",
            "gohan":      "Son Gohan",
            "krillin":    "Kuririn",
            "trunks":     "Trunks",
            "freezer":    "Freeza",
            "cell":       "Cell",
            "majin_buu":  "Majin Buu",
            "yamcha":     "Yamcha",
            "tenshinhan": "Tenshinhan",
            "android_18": "Jinzouningen 18-gou",
            "broly":      "Broly",
            "beerus":     "Beerus",
        },
    },
    "naruto": {
        "source": "jikan",
        "jikan_anime": ["Naruto: Shippuuden", "Naruto"],
        "logo": ("wikipedia", "Naruto Shippuden"),
        "personajes": {
            "naruto":     "Naruto Uzumaki",
            "sasuke":     "Sasuke Uchiha",
            "sakura":     "Sakura Haruno",
            "kakashi":    "Kakashi Hatake",
            "itachi":     "Itachi Uchiha",
            "jiraiya":    "Jiraiya",
            "orochimaru": "Orochimaru",
            "gaara":      "Gaara",
            "rock_lee":   "Rock Lee",
            "neji":       "Neji Hyuga",
            "hinata":     "Hinata Hyuga",
            "shikamaru":  "Shikamaru Nara",
            "pain":       "Pain",
            "madara":     "Madara Uchiha",
        },
    },
    "one_piece": {
        "source": "jikan",
        "jikan_anime": ["One Piece"],
        "logo": ("wikipedia", "One Piece"),
        "personajes": {
            "luffy":      "Monkey D. Luffy",
            "zoro":       "Roronoa Zoro",
            "nami":       "Nami",
            "sanji":      "Sanji",
            "usopp":      "Usopp",
            "chopper":    "Tony Tony Chopper",
            "robin":      "Nico Robin",
            "franky":     "Franky",
            "brook":      "Brook",
            "ace":        "Portgas D. Ace",
            "shanks":     "Shanks",
            "mihawk":     "Dracule Mihawk",
            "doflamingo": "Donquixote Doflamingo",
            "kaido":      "Kaidou",
        },
    },
    "demon_slayer": {
        "source": "jikan",
        "jikan_anime": ["Kimetsu no Yaiba"],
        "logo": ("wikipedia", "Demon Slayer: Kimetsu no Yaiba"),
        "personajes": {
            "tanjiro":  "Tanjirou Kamado",
            "nezuko":   "Nezuko Kamado",
            "zenitsu":  "Zenitsu Agatsuma",
            "inosuke":  "Inosuke Hashibira",
            "rengoku":  "Kyoujurou Rengoku",
            "giyu":     "Giyuu Tomioka",
            "shinobu":  "Shinobu Kochou",
            "tengen":   "Tengen Uzui",
            "muichiro": "Muichirou Tokitou",
            "mitsuri":  "Mitsuri Kanroji",
            "obanai":   "Obanai Iguro",
            "sanemi":   "Sanemi Shinazugawa",
            "muzan":    "Muzan Kibutsuji",
            "akaza":    "Akaza",
        },
    },
    "attack_on_titan": {
        "source": "jikan",
        "jikan_anime": ["Shingeki no Kyojin"],
        "logo": ("wikipedia", "Attack on Titan"),
        "personajes": {
            "eren":      "Eren Yeager",
            "mikasa":    "Mikasa Ackerman",
            "armin":     "Armin Arlert",
            "levi":      "Levi Ackerman",
            "erwin":     "Erwin Smith",
            "hange":     "Hange Zoe",
            "historia":  "Krista Lenz",
            "jean":      "Jean Kirschtein",
            "connie":    "Connie Springer",
            "sasha":     "Sasha Braus",
            "reiner":    "Reiner Braun",
            "bertholdt": "Bertolt Hoover",
            "annie":     "Annie Leonhart",
            "zeke":      "Zeke Yeager",
        },
    },
    # ── Live action (Wikipedia) ─────────────────────────────────────────────
    "marvel": {
        "source": "wikipedia",
        "logo": "Marvel Studios",
        "personajes": {
            "iron_man":        "Iron Man (Marvel Cinematic Universe)",
            "spider_man":      "Spider-Man (Marvel Cinematic Universe)",
            "thor":            "Thor (Marvel Cinematic Universe)",
            "hulk":            "Hulk (Marvel Cinematic Universe)",
            "captain_america": "Captain America (Marvel Cinematic Universe)",
            "black_widow":     "Black Widow (Natasha Romanoff)",
            "loki":            "Loki (Marvel Cinematic Universe)",
            "thanos":          "Thanos (Marvel Cinematic Universe)",
            "doctor_strange":  "Doctor Strange (Marvel Cinematic Universe)",
            "black_panther":   "Black Panther (Marvel Cinematic Universe)",
            "ant_man":         "Ant-Man (Marvel Cinematic Universe)",
            "scarlet_witch":   "Wanda Maximoff (Marvel Cinematic Universe)",
            "vision":          "Vision (Marvel Cinematic Universe)",
            "hawkeye":         "Hawkeye (Marvel Cinematic Universe)",
        },
    },
    "dc": {
        "source": "wikipedia",
        "logo": "DC Comics",
        "personajes": {
            "batman":        "Batman",
            "superman":      "Superman",
            "wonder_woman":  "Wonder Woman",
            "flash":         "Flash (Barry Allen)",
            "aquaman":       "Aquaman",
            "green_lantern": "Green Lantern",
            "cyborg":        "Cyborg (DC Comics)",
            "joker":         "Joker (character)",
            "harley_quinn":  "Harley Quinn",
            "catwoman":      "Catwoman",
            "robin":         "Robin (character)",
            "lex_luthor":    "Lex Luthor",
            "deathstroke":   "Deathstroke",
            "darkseid":      "Darkseid",
        },
    },
    "stranger_things": {
        "source": "wikipedia",
        "logo": "Stranger Things",
        "personajes": {
            "eleven":   "Eleven (Stranger Things)",
            "mike":     "Mike Wheeler",
            "dustin":   "Dustin Henderson",
            "lucas":    "Lucas Sinclair",
            "will":     "Will Byers",
            "max":      "Max Mayfield",
            "nancy":    "Nancy Wheeler",
            "jonathan": "Charlie Heaton",
            "steve":    "Steve Harrington",
            "robin":    "Robin Buckley",
            "eddie":    "Eddie Munson",
            "hopper":   "Jim Hopper",
            "joyce":    "Joyce Byers",
            "vecna":    "Vecna (Stranger Things)",
        },
    },
    "harry_potter": {
        "source": "wikipedia",
        "logo": "Harry Potter",
        "personajes": {
            "harry":      "Harry Potter (character)",
            "hermione":   "Hermione Granger",
            "ron":        "Ron Weasley",
            "dumbledore": "Albus Dumbledore",
            "voldemort":  "Lord Voldemort",
            "snape":      "Severus Snape",
            "hagrid":     "Rubeus Hagrid",
            "mcgonagall": "Minerva McGonagall",
            "draco":      "Draco Malfoy",
            "sirius":     "Sirius Black",
            "lupin":      "Remus Lupin",
            "bellatrix":  "Bellatrix Lestrange",
            "luna":       "Luna Lovegood",
            "neville":    "Neville Longbottom",
        },
    },
    "the_office": {
        "source": "wikipedia",
        "logo": "Dunder Mifflin",
        "personajes": {
            "michael": "Michael Scott (The Office)",
            "jim":     "Jim Halpert",
            "pam":     "Pam Beesly",
            "dwight":  "Dwight Schrute",
            "andy":    "Andy Bernard",
            "kevin":   "Kevin Malone",
            "oscar":   "Oscar Martinez (The Office)",
            "angela":  "Angela Martin",
            "stanley": "Leslie David Baker",
            "kelly":   "Kelly Kapoor",
            "ryan":    "Ryan Howard (The Office)",
            "phyllis": "Phyllis Smith",
            "creed":   "Creed Bratton",
            "toby":    "Paul Lieberstein",
        },
    },
    "breaking_bad": {
        "source": "wikipedia",
        "logo": "Breaking Bad",
        "personajes": {
            "walter":    "Walter White (Breaking Bad)",
            "jesse":     "Jesse Pinkman",
            "saul":      "Saul Goodman",
            "gus":       "Gus Fring",
            "mike":      "Mike Ehrmantraut",
            "hank":      "Hank Schrader",
            "skyler":    "Skyler White",
            "marie":     "Marie Schrader",
            "walter_jr": "Walter White Jr.",
            "tuco":      "Tuco Salamanca",
            "hector":    "Hector Salamanca",
            "lalo":      "Lalo Salamanca",
            "nacho":     "Nacho Varga",
            "todd":      "Todd Alquist",
        },
    },
    "super_mario": {
        "source": "wikipedia",
        "logo": "Super Mario",
        "personajes": {
            "mario":       "Mario",
            "luigi":       "Luigi (Nintendo)",
            "peach":       "Princess Peach",
            "daisy":       "Princess Daisy",
            "bowser":      "Bowser",
            "yoshi":       "Yoshi",
            "toad":        "Toad (Nintendo)",
            "wario":       "Wario",
            "waluigi":     "Waluigi",
            "donkey_kong": "Donkey Kong (character)",
            "bowser_jr":   "Bowser Jr.",
            "rosalina":    "Rosalina (Mario)",
            "koopa":       "Koopa Troopa",
            "goomba":      "Goomba",
        },
    },
    "disney": {
        "source": "wikipedia",
        "logo": "The Walt Disney Company",
        "personajes": {
            "mickey":  "Mickey Mouse",
            "minnie":  "Minnie Mouse",
            "donald":  "Donald Duck",
            "goofy":   "Goofy",
            "elsa":    "Elsa (Frozen)",
            "anna":    "Frozen II",
            "simba":   "Simba",
            "ariel":   "Ariel (The Little Mermaid)",
            "aladdin": "Aladdin (Disney character)",
            "jasmine": "Princess Jasmine",
            "stitch":  "Stitch (Lilo & Stitch)",
            "woody":   "Sheriff Woody",
            "buzz":    "Buzz Lightyear",
            "moana":   "Moana (character)",
        },
    },
}


# ─── HTTP HELPERS ─────────────────────────────────────────────────────────────

def http_get_json(url, *, reintentos=3):
    """GET con JSON. Reintenta con backoff exponencial cuando hay 429 o 503."""
    espera = 2.0
    ultimo_error = None
    for intento in range(reintentos):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            ultimo_error = e
            if e.code in (429, 503) and intento < reintentos - 1:
                time.sleep(espera)
                espera *= 2
                continue
            raise
        except Exception as e:
            ultimo_error = e
            if intento < reintentos - 1:
                time.sleep(espera)
                espera *= 2
                continue
            raise
    if ultimo_error:
        raise ultimo_error


def http_download(url, dest, *, reintentos=3):
    """Descarga binaria con reintentos."""
    espera = 2.0
    ultimo_error = None
    for intento in range(reintentos):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=TIMEOUT) as r, open(dest, "wb") as f:
                shutil.copyfileobj(r, f)
            return
        except urllib.error.HTTPError as e:
            ultimo_error = e
            if e.code in (429, 503) and intento < reintentos - 1:
                time.sleep(espera)
                espera *= 2
                continue
            raise
        except Exception as e:
            ultimo_error = e
            if intento < reintentos - 1:
                time.sleep(espera)
                espera *= 2
                continue
            raise
    if ultimo_error:
        raise ultimo_error


# ─── RESOLVERS DE URL DE IMAGEN POR SOURCE ────────────────────────────────────

def pokeapi_image_url(name):
    data = http_get_json(f"https://pokeapi.co/api/v2/pokemon/{name.lower()}")
    art = data["sprites"]["other"]["official-artwork"]["front_default"]
    if not art:
        raise RuntimeError("Pokémon sin official-artwork")
    return art


def jikan_image_url(query):
    """Búsqueda libre de personaje (sin filtro de anime). Usa solo cuando no se
    pueda restringir por anime; sino, usar jikan_image_url_in_anime."""
    q = urllib.parse.quote(query)
    url = (
        f"https://api.jikan.moe/v4/characters?q={q}"
        "&order_by=favorites&sort=desc&limit=1"
    )
    data = http_get_json(url)
    results = data.get("data") or []
    if not results:
        raise RuntimeError(f"Jikan no devolvió personajes para «{query}»")
    return _imagen_de_personaje_jikan(results[0])


# ─── JIKAN ANIME-FILTERED LOOKUP ──────────────────────────────────────────────
# Para evitar que «Hinata» (Naruto) devuelva al Hinata de Haikyuu por ser más
# popular, bajamos la lista de personajes del anime correcto UNA vez por anime
# y buscamos por nombre dentro de esa lista.

_anime_chars_cache = {}  # anime_title -> [characters]


def _imagen_de_personaje_jikan(personaje):
    """Recibe un dict de personaje de Jikan, devuelve la URL de imagen."""
    images = personaje.get("images", {}) or {}
    if "webp" in images and images["webp"].get("image_url"):
        return images["webp"]["image_url"]
    return images["jpg"]["image_url"]


def _normalizar_nombre(s):
    """Hace comparaciones de nombres robustas a romanizaciones distintas
    (Hyuga vs Hyuuga, Tanjiro vs Tanjirou, Goku vs Gokuu)."""
    s = s.lower().strip()
    # Quitar puntos, comas, comillas
    for c in ".,'\"":
        s = s.replace(c, "")
    # Colapsar vocales dobles (uu→u, oo→o) y ou→o para tratar romanizaciones
    s = s.replace("uu", "u").replace("oo", "o").replace("ou", "o")
    return s


def _cargar_personajes_anime(anime_titulo):
    """Busca el anime por título y devuelve su lista de personajes (con
    images). Caché en memoria para no spammear la API."""
    if anime_titulo in _anime_chars_cache:
        return _anime_chars_cache[anime_titulo]

    q = urllib.parse.quote(anime_titulo)
    # Estrategia 1: si parece serie de TV (no contiene "Movie"/":" indicando
    # spin-off o película), filtrar por type=tv para evitar películas piloto
    # de poco contenido (ej: la película original de One Piece de 1998 tiene
    # solo 14 personajes; queremos la serie de TV que tiene cientos).
    parece_pelicula = (
        ":" in anime_titulo
        or "Movie" in anime_titulo
        or "Broly" in anime_titulo
    )
    if not parece_pelicula:
        search = http_get_json(
            f"https://api.jikan.moe/v4/anime?q={q}&limit=1&type=tv"
        )
        if search.get("data"):
            anime_id = search["data"][0]["mal_id"]
        else:
            # Sin resultados como TV, probar sin filtro
            search = http_get_json(f"https://api.jikan.moe/v4/anime?q={q}&limit=1")
            if not search.get("data"):
                _anime_chars_cache[anime_titulo] = []
                return []
            anime_id = search["data"][0]["mal_id"]
    else:
        search = http_get_json(f"https://api.jikan.moe/v4/anime?q={q}&limit=1")
        if not search.get("data"):
            _anime_chars_cache[anime_titulo] = []
            return []
        anime_id = search["data"][0]["mal_id"]
    time.sleep(0.4)
    chars = http_get_json(
        f"https://api.jikan.moe/v4/anime/{anime_id}/characters"
    )
    lista = chars.get("data", []) or []
    _anime_chars_cache[anime_titulo] = lista
    return lista


def jikan_image_url_in_anime(query, anime_titulos):
    """Busca el personaje DENTRO de la lista oficial de personajes del anime.
    Esto garantiza que «Hinata» en Naruto sea Hinata Hyuga, no Hinata Shōyō."""
    # Reunir todos los personajes de los animes declarados (DBZ + DBS, etc.)
    todos = []
    for titulo in anime_titulos:
        try:
            personajes = _cargar_personajes_anime(titulo)
            todos.extend(personajes)
        except Exception:
            continue

    if not todos:
        # Fallback: búsqueda libre
        return jikan_image_url(query)

    q_norm = _normalizar_nombre(query)
    q_palabras = q_norm.split()

    # Estrategia 1: match exacto normalizado
    for c in todos:
        nombre = c.get("character", {}).get("name", "")
        if _normalizar_nombre(nombre) == q_norm:
            return _imagen_de_personaje_jikan(c["character"])

    # Estrategia 2: todas las palabras del query aparecen en el nombre
    for c in todos:
        nombre = _normalizar_nombre(c.get("character", {}).get("name", ""))
        if q_palabras and all(w in nombre for w in q_palabras):
            return _imagen_de_personaje_jikan(c["character"])

    # Estrategia 3: la primera palabra del query aparece en el nombre
    if q_palabras:
        primera = q_palabras[0]
        candidatos = []
        for c in todos:
            nombre = _normalizar_nombre(c.get("character", {}).get("name", ""))
            if primera in nombre:
                candidatos.append(c["character"])
        if candidatos:
            # Preferir el nombre más corto (más probable que sea el personaje principal)
            candidatos.sort(key=lambda x: len(x.get("name", "")))
            return _imagen_de_personaje_jikan(candidatos[0])

    # Estrategia 4 (fallback): búsqueda global por nombre y verificar que el
    # personaje aparece en al menos uno de los anime declarados. Útil para
    # personajes que MAL escribe muy distinto (Krillin/Kuririn, Freezer/Frieza)
    # o que están en spin-offs no incluidos en la lista del anime principal.
    try:
        return _busqueda_global_con_verificacion(query, anime_titulos)
    except Exception:
        pass

    raise RuntimeError(
        f"no se encontró «{query}» en la lista de personajes de {anime_titulos}"
    )


def _busqueda_global_con_verificacion(query, anime_titulos):
    """Busca el personaje globalmente y verifica que pertenece a uno de los
    animes declarados antes de devolver su imagen."""
    q = urllib.parse.quote(query)
    url = (
        f"https://api.jikan.moe/v4/characters?q={q}"
        "&order_by=favorites&sort=desc&limit=5"
    )
    data = http_get_json(url)
    candidatos = data.get("data") or []
    if not candidatos:
        raise RuntimeError(f"sin resultados globales para «{query}»")

    # Normalizar títulos de anime esperados
    animes_esperados = {_normalizar_nombre(a) for a in anime_titulos}
    # Agregar variantes comunes (DBZ, DBS, AoT, etc.)
    variantes = set()
    for a in anime_titulos:
        a_norm = _normalizar_nombre(a)
        if "dragon ball" in a_norm:
            variantes.add("dragon ball")
        if "naruto" in a_norm:
            variantes.add("naruto")
        if "one piece" in a_norm:
            variantes.add("one piece")
        if "kimetsu" in a_norm or "demon slayer" in a_norm:
            variantes.add("kimetsu no yaiba")
            variantes.add("demon slayer")
        if "shingeki" in a_norm or "attack on titan" in a_norm:
            variantes.add("shingeki no kyojin")
            variantes.add("attack on titan")
    animes_esperados |= variantes

    for cand in candidatos:
        char_id = cand.get("mal_id")
        if not char_id:
            continue
        time.sleep(0.4)
        try:
            full = http_get_json(
                f"https://api.jikan.moe/v4/characters/{char_id}/anime"
            )
        except Exception:
            continue
        anime_list = full.get("data") or []
        for entry in anime_list:
            titulo = _normalizar_nombre(
                entry.get("anime", {}).get("title", "")
            )
            # Match si el título del anime esperado está contenido en el del candidato
            for esperado in animes_esperados:
                if esperado and esperado in titulo:
                    return _imagen_de_personaje_jikan(cand)

    raise RuntimeError(f"«{query}» encontrado globalmente pero no en los animes esperados")


def _wikipedia_pageimage(titulo):
    """Pide directamente la imagen principal de un artículo vía la API
    pageimages. A veces devuelve imagen cuando el endpoint summary no.
    Devuelve URL o None."""
    encoded = urllib.parse.quote(titulo)
    data = http_get_json(
        f"https://en.wikipedia.org/w/api.php?action=query&titles={encoded}"
        "&prop=pageimages&pithumbsize=600&format=json&redirects=1"
    )
    pages = data.get("query", {}).get("pages", {}) or {}
    for _, page in pages.items():
        thumb = page.get("thumbnail")
        if thumb and thumb.get("source"):
            return thumb["source"]
        original = page.get("original")
        if original and original.get("source"):
            return original["source"]
    return None


def wikipedia_image_url(query):
    # Estrategia 1: REST summary del título exacto
    encoded = urllib.parse.quote(query.replace(" ", "_"))
    titulo_final = query
    try:
        data = http_get_json(
            f"https://en.wikipedia.org/api/rest_v1/page/summary/{encoded}"
        )
        img = data.get("originalimage") or data.get("thumbnail")
        if img and img.get("source"):
            return img["source"]
        # Hubo summary pero sin imagen — probar pageimages
        titulo_final = data.get("title") or query
    except Exception:
        pass

    # Estrategia 2: pageimages API (a veces tiene imagen aunque summary no)
    try:
        img = _wikipedia_pageimage(titulo_final)
        if img:
            return img
    except Exception:
        pass

    # Estrategia 3: búsqueda → primer resultado → summary o pageimages
    sq = urllib.parse.quote(query)
    search = http_get_json(
        f"https://en.wikipedia.org/w/api.php?action=query&list=search"
        f"&srsearch={sq}&srlimit=3&format=json"
    )
    hits = search.get("query", {}).get("search", []) or []
    if not hits:
        raise RuntimeError(f"Wikipedia no encontró «{query}»")

    for hit in hits:
        title = hit["title"]
        encoded2 = urllib.parse.quote(title.replace(" ", "_"))
        try:
            data = http_get_json(
                f"https://en.wikipedia.org/api/rest_v1/page/summary/{encoded2}"
            )
            img = data.get("originalimage") or data.get("thumbnail")
            if img and img.get("source"):
                return img["source"]
        except Exception:
            pass
        try:
            img = _wikipedia_pageimage(title)
            if img:
                return img
        except Exception:
            pass

    raise RuntimeError(f"sin imagen para «{query}» (probadas {len(hits)} variantes)")


def resolve_url(source, query, *, jikan_anime=None):
    if source == "pokeapi":
        return pokeapi_image_url(query)
    if source == "jikan":
        if jikan_anime:
            return jikan_image_url_in_anime(query, jikan_anime)
        return jikan_image_url(query)
    if source == "wikipedia":
        return wikipedia_image_url(query)
    raise ValueError(f"source desconocido: {source}")


# ─── PROCESO PRINCIPAL ────────────────────────────────────────────────────────

def extension_de(url):
    path = url.split("?")[0]
    ext = os.path.splitext(path)[1].lower()
    if ext in (".png", ".jpg", ".jpeg", ".webp", ".gif"):
        return ext
    return ".jpg"


def descargar_item(source, query, carpeta, nombre_archivo, *, jikan_anime=None):
    # Si ya existe un archivo con ese nombre base (cualquier extensión), skipear.
    # Permite reanudar entre corridas sin redescargar lo bueno.
    for ext_existente in (".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg"):
        candidato = os.path.join(carpeta, f"{nombre_archivo}{ext_existente}")
        if os.path.exists(candidato):
            return candidato

    url = resolve_url(source, query, jikan_anime=jikan_anime)
    ext = extension_de(url)
    destino = os.path.join(carpeta, f"{nombre_archivo}{ext}")
    http_download(url, destino)
    return destino


def _delay_para(source):
    """Wikipedia tiene rate limit más agresivo. Le damos más tiempo entre calls."""
    return 1.2 if source == "wikipedia" else 0.4


def _ya_existe(carpeta, nombre_archivo):
    for ext in (".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg"):
        if os.path.exists(os.path.join(carpeta, f"{nombre_archivo}{ext}")):
            return True
    return False


def main():
    total = sum(1 + len(t["personajes"]) for t in TEMAS.values())  # +1 = logo
    descargadas = 0
    skippeadas = 0
    errores = []

    print(f"\n{'='*60}")
    print(f"  Procesando {total} imágenes en {len(TEMAS)} carpetas")
    print(f"  Fuentes: PokeAPI, Jikan (MyAnimeList), Wikipedia")
    print(f"  (Los archivos ya existentes se mantienen)")
    print(f"{'='*60}\n")

    for tema, config in TEMAS.items():
        carpeta = f"assets/images/{tema}"
        os.makedirs(carpeta, exist_ok=True)
        print(f"\n📁 {carpeta}  ({config['source']})")

        # Logo
        logo_cfg = config["logo"]
        if isinstance(logo_cfg, tuple):
            logo_source, logo_query = logo_cfg
        else:
            logo_source, logo_query = config["source"], logo_cfg
        if _ya_existe(carpeta, "logo"):
            skippeadas += 1
            print(f"  ⊙ logo  (ya existe, omitido)")
        else:
            try:
                ruta = descargar_item(logo_source, logo_query, carpeta, "logo")
                descargadas += 1
                print(f"  ✓ logo  → {os.path.basename(ruta)}")
            except Exception as e:
                errores.append(f"{carpeta}/logo — {e}")
                print(f"  ✗ logo — {e}")
            time.sleep(_delay_para(logo_source))

        # Personajes
        jikan_anime = config.get("jikan_anime")  # solo aplica si source==jikan
        for nombre_archivo, query in config["personajes"].items():
            if _ya_existe(carpeta, nombre_archivo):
                skippeadas += 1
                print(f"  ⊙ {nombre_archivo}  (ya existe, omitido)")
                continue
            try:
                ruta = descargar_item(
                    config["source"],
                    query,
                    carpeta,
                    nombre_archivo,
                    jikan_anime=jikan_anime,
                )
                descargadas += 1
                print(f"  ✓ {nombre_archivo}  → {os.path.basename(ruta)}")
            except Exception as e:
                errores.append(f"{carpeta}/{nombre_archivo} — {e}")
                print(f"  ✗ {nombre_archivo} — {e}")
            time.sleep(_delay_para(config["source"]))

    print(f"\n{'='*60}")
    print(f"  ✅ Descargadas nuevas: {descargadas}")
    print(f"  ⊙ Skippeadas (ya existían): {skippeadas}")
    print(f"  📊 Total OK: {descargadas + skippeadas}/{total}")
    if errores:
        print(f"  ❌ Errores ({len(errores)}):")
        for e in errores:
            print(f"     • {e}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
