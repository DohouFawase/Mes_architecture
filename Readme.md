# Architecture Laravel générique — README

Ce document explique ce que génère `setup-laravel-architecture.sh`, pourquoi chaque
dossier existe, et ce qu'il te reste à compléter toi-même (logique métier).

---

## 1. Avant de lancer le script

Édite le tableau en haut du fichier :

```bash
MODULES=(
    "User"
)
```

Mets-y une entrée par entité/agrégat principal de ton projet. Exemples :

- Blog : `("Post" "Category" "Comment")`
- CRM : `("Contact" "Deal" "Pipeline")`
- SaaS : `("Workspace" "Project" "Task")`

Chaque nom doit être au singulier et en PascalCase (`Product`, pas `products`).

---

## 2. Vue d'ensemble des couches

```
app/
├── Domain/<Module>/Models     → entités métier (Eloquent)
├── Application/
│   ├── Actions                → une action métier = une classe = un cas d'usage
│   ├── Services                → orchestration, regroupe plusieurs actions/repos
│   ├── DTOs                    → objets de transfert de données typés
│   └── Queries                 → lectures complexes (hors CRUD simple)
├── Repositories/
│   ├── Contracts               → interfaces (ce qu'on peut faire)
│   └── Eloquent                → implémentation (comment on le fait avec Eloquent)
├── Http/
│   ├── Controllers/Api/V1      → un dossier par module, fait le lien HTTP ↔ Application
│   ├── Requests/Api/V1         → validation des entrées
│   └── Resources/Api/V1        → formatage des sorties JSON
├── Policies                    → autorisations par module
├── Providers                   → RepositoryServiceProvider (bindings)
├── Events / Listeners / Jobs   → asynchrone et réactions à des événements
├── Exceptions                  → exceptions métier génériques
├── Enums                       → états/valeurs fixes
└── Support                     → utilitaires transverses (ApiResponse, etc.)
```

**Principe** : `Controller` ne parle jamais directement à `Eloquent`. Il passe par
`Service`/`Action`, qui passe par `Repository` (interface), qui seul connaît Eloquent.
Ça te permet de changer la persistance (cache, API externe, autre ORM) sans toucher
au reste.

---

## 3. Détail des fichiers communs (non liés à un module)

| Fichier | Rôle | À faire |
|---|---|---|
| `Repositories/Contracts/RepositoryInterface.php` | Contrat générique CRUD (`all`, `find`, `create`, `update`, `delete`) | Rien, sauf si tu veux ajouter une méthode commune à tous les repos (ex: `paginate`) |
| `Repositories/Eloquent/BaseRepository.php` | Implémentation générique du contrat ci-dessus | Rien à modifier en général |
| `Application/Services/BaseService.php` | Classe mère de tous les services, reçoit un `RepositoryInterface` | Rien |
| `Application/Actions/BaseAction.php` | Contrat `execute()` pour toute action | Rien |
| `Exceptions/DomainException.php` | Exception métier racine | Étends-la pour tes cas spécifiques |
| `Exceptions/NotFoundException.php` | Ressource introuvable | À lever dans tes repos/services |
| `Exceptions/ValidationException.php` | Règle métier violée (différent de la validation HTTP) | À lever dans tes Actions |
| `Support/ApiResponse.php` | Trait `success()` / `error()` pour réponses JSON uniformes | À utiliser dans tes Controllers (`use ApiResponse;`) |
| `Models/Concerns/HasUuid.php` | Trait pour clé primaire UUID | À ajouter (`use HasUuid;`) sur les modèles qui en ont besoin |
| `Enums/Status.php` | Exemple d'enum générique (`active`/`inactive`/`pending`) | À dupliquer/adapter par domaine (ex: `OrderStatus`, `TaskStatus`) |
| `Http/Middleware/RequestId.php` | Ajoute un header `X-Request-ID` traçable | Rien, juste à enregistrer dans `bootstrap/app.php` si tu veux l'activer globalement |
| `Http/Middleware/ForceJsonResponse.php` | Force les réponses API en JSON | Idem |

---

## 4. Détail des fichiers générés **par module** (ex: `Product`)

| Fichier | Rôle | À faire |
|---|---|---|
| `Domain/Product/Models/Product.php` | Modèle Eloquent | Ajouter `$fillable`, relations, casts |
| `database/migrations/..._create_products_table.php` | Migration | Définir les colonnes |
| `database/factories/ProductFactory.php` | Factory de test | Définir les données factices |
| `Http/Controllers/Api/V1/Product/ProductController.php` | Endpoints REST | Implémenter `index/store/show/update/destroy`, appeler les Actions/Services |
| `Http/Requests/Api/V1/Product/StoreProductRequest.php` | Validation création | Ajouter les règles dans `rules()` |
| `Http/Requests/Api/V1/Product/UpdateProductRequest.php` | Validation mise à jour | Idem |
| `Http/Resources/Api/V1/Product/ProductResource.php` | Format JSON de sortie | Définir `toArray()` |
| `Policies/ProductPolicy.php` | Autorisations (`view`, `create`, `update`, `delete`...) | Implémenter la logique d'accès |
| `Repositories/Contracts/ProductRepositoryInterface.php` | Contrat spécifique au module | Ajouter les méthodes propres à Product (ex: `findBySlug`) |
| `Repositories/Eloquent/ProductRepository.php` | Implémentation | Implémenter les méthodes ajoutées au contrat |
| `Application/Services/ProductService.php` | Orchestration métier | Écrire la logique qui combine plusieurs actions/repos |
| `Application/Actions/CreateProductAction.php` | Cas d'usage "créer" | Corps de `execute()` |
| `Application/Actions/UpdateProductAction.php` | Cas d'usage "modifier" | Corps de `execute()` |
| `Application/Actions/DeleteProductAction.php` | Cas d'usage "supprimer" | Corps de `execute()` |
| `Application/DTOs/ProductData.php` | Objet typé pour transporter les données | Ajouter les propriétés (`public string $name`, etc.) |
| `tests/Feature/ProductApiTest.php` | Test feature vide | Écrire les vrais tests d'API |

---

## 5. Le binding automatique

`Providers/RepositoryServiceProvider.php` est généré avec, pour chaque module :

```php
$this->app->bind(
    \App\Repositories\Contracts\ProductRepositoryInterface::class,
    \App\Repositories\Eloquent\ProductRepository::class
);
```

Ça permet d'injecter `ProductRepositoryInterface` dans un constructeur (Service, Action,
Controller) sans jamais dépendre directement d'Eloquent.

⚠️ **Étape manuelle obligatoire** : enregistre ce provider dans
`bootstrap/providers.php` (Laravel 11+) ou `config/app.php` (Laravel ≤10) :

```php
App\Providers\RepositoryServiceProvider::class,
```

---

## 6. Ce qu'il te reste à faire, dans l'ordre conseillé

1. **Migrations** — colonnes de chaque table dans `database/migrations`.
2. **Modèles** — `$fillable`, `casts`, relations Eloquent.
3. **Form Requests** — règles de validation HTTP.
4. **Repositories** — méthodes spécifiques par module si besoin (recherche, filtres...).
5. **Actions/Services** — logique métier réelle (c'est la partie que tu voulais garder pour toi).
6. **Resources** — format de sortie JSON.
7. **Policies** — règles d'autorisation.
8. **Routes** — `routes/api.php`, pointant vers les Controllers.
9. **Tests** — remplacer les `test_example` par de vrais scénarios.
10. **Enregistrer** `RepositoryServiceProvider` (voir section 5).

---

## 7. Pour ajouter un module plus tard

Pas besoin de relancer tout le script : ajoute simplement le nom au tableau
`MODULES` et relance-le. Comme chaque section (`mkdir -p`, `cat >`) écrase ou
recrée uniquement les fichiers concernés, les modules déjà en place restent
intacts (attention quand même à ne pas relancer sur un module déjà modifié à
la main, sinon tes changements seront écrasés).


chmod +x install-laravel.sh
./install-laravel.sh