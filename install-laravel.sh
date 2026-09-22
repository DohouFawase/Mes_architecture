#!/usr/bin/env bash

set -e

echo "🚀 Installation de l'architecture Laravel (générique / scalable)..."

# ============================================================
# 0. CONFIGURATION — À ÉDITER SELON TON PROJET
# ============================================================
# Liste tes modules métier ici (un par entité/agrégat principal).
# Exemple pour un blog : ("Post" "Category" "Comment")
# Exemple pour un CRM  : ("Contact" "Deal" "Pipeline")
MODULES=(
    "User"
)

# ============================================================
# 1. Vérification
# ============================================================

if [ ! -f "artisan" ]; then
    echo "❌ Erreur : lance ce script depuis la racine du projet Laravel."
    exit 1
fi

echo "✅ Projet Laravel détecté."

# ============================================================
# 2. Dossiers communs (indépendants des modules)
# ============================================================

mkdir -p \
app/Domain \
app/Application/Actions \
app/Application/DTOs \
app/Application/Services \
app/Application/Queries \
app/Repositories/Contracts \
app/Repositories/Eloquent \
app/Infrastructure/Persistence \
app/Infrastructure/Cache \
app/Infrastructure/Search \
app/Infrastructure/ExternalServices \
app/Http/Controllers/Api/V1 \
app/Http/Requests/Api/V1 \
app/Http/Resources/Api/V1 \
app/Http/Middleware \
app/Policies \
app/Providers \
app/Jobs \
app/Events \
app/Listeners \
app/Exceptions \
app/Enums \
app/Support \
app/Models/Concerns \
tests/Unit/Domain \
tests/Feature \
tests/Integration

echo "✅ Dossiers de base créés."

# ============================================================
# 3. Contrat générique de Repository
# ============================================================

cat > app/Repositories/Contracts/RepositoryInterface.php <<'PHP'
<?php

namespace App\Repositories\Contracts;

interface RepositoryInterface
{
    public function all(array $columns = ['*']): mixed;

    public function find(string $id): mixed;

    public function create(array $data): mixed;

    public function update(string $id, array $data): mixed;

    public function delete(string $id): bool;
}
PHP

# ============================================================
# 4. Repository de base (implémentation générique Eloquent)
# ============================================================

cat > app/Repositories/Eloquent/BaseRepository.php <<'PHP'
<?php

namespace App\Repositories\Eloquent;

use App\Repositories\Contracts\RepositoryInterface;
use Illuminate\Database\Eloquent\Model;

abstract class BaseRepository implements RepositoryInterface
{
    public function __construct(protected Model $model)
    {
    }

    public function all(array $columns = ['*']): mixed
    {
        return $this->model->select($columns)->get();
    }

    public function find(string $id): mixed
    {
        return $this->model->find($id);
    }

    public function create(array $data): mixed
    {
        return $this->model->create($data);
    }

    public function update(string $id, array $data): mixed
    {
        $record = $this->model->findOrFail($id);
        $record->update($data);

        return $record;
    }

    public function delete(string $id): bool
    {
        return (bool) $this->model->destroy($id);
    }
}
PHP

echo "📚 RepositoryInterface + BaseRepository créés."

# ============================================================
# 5. Service et Action de base
# ============================================================

cat > app/Application/Services/BaseService.php <<'PHP'
<?php

namespace App\Application\Services;

use App\Repositories\Contracts\RepositoryInterface;

abstract class BaseService
{
    public function __construct(protected RepositoryInterface $repository)
    {
    }
}
PHP

cat > app/Application/Actions/BaseAction.php <<'PHP'
<?php

namespace App\Application\Actions;

abstract class BaseAction
{
    abstract public function execute(array $data = []): mixed;
}
PHP

echo "⚙️ BaseService + BaseAction créés."

# ============================================================
# 6. Exceptions génériques
# ============================================================

cat > app/Exceptions/DomainException.php <<'PHP'
<?php

namespace App\Exceptions;

use Exception;

class DomainException extends Exception
{
}
PHP

cat > app/Exceptions/NotFoundException.php <<'PHP'
<?php

namespace App\Exceptions;

class NotFoundException extends DomainException
{
}
PHP

cat > app/Exceptions/ValidationException.php <<'PHP'
<?php

namespace App\Exceptions;

class ValidationException extends DomainException
{
}
PHP

echo "❌ Exceptions génériques créées."

# ============================================================
# 7. Trait de réponse API standardisée
# ============================================================

cat > app/Support/ApiResponse.php <<'PHP'
<?php

namespace App\Support;

trait ApiResponse
{
    protected function success(mixed $data = null, string $message = 'OK', int $code = 200)
    {
        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => $data,
        ], $code);
    }

    protected function error(string $message = 'Erreur', int $code = 400, mixed $errors = null)
    {
        return response()->json([
            'success' => false,
            'message' => $message,
            'errors' => $errors,
        ], $code);
    }
}
PHP

echo "📡 Trait ApiResponse créé."

# ============================================================
# 8. UUID Trait
# ============================================================

cat > app/Models/Concerns/HasUuid.php <<'PHP'
<?php

namespace App\Models\Concerns;

use Illuminate\Support\Str;

trait HasUuid
{
    protected static function bootHasUuid(): void
    {
        static::creating(function ($model) {
            if (empty($model->{$model->getKeyName()})) {
                $model->{$model->getKeyName()} = (string) Str::uuid();
            }
        });
    }

    public function getIncrementing(): bool
    {
        return false;
    }

    public function getKeyType(): string
    {
        return 'string';
    }
}
PHP

echo "🔑 HasUuid créé."

# ============================================================
# 9. Enum générique d'exemple
# ============================================================

cat > app/Enums/Status.php <<'PHP'
<?php

namespace App\Enums;

// Exemple générique — adapte ou duplique par domaine (ex: OrderStatus, UserStatus...)
enum Status: string
{
    case ACTIVE = 'active';
    case INACTIVE = 'inactive';
    case PENDING = 'pending';
}
PHP

echo "🔖 Enum d'exemple créé."

# ============================================================
# 10. Middleware utilitaires
# ============================================================

cat > app/Http/Middleware/RequestId.php <<'PHP'
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

class RequestId
{
    public function handle(Request $request, Closure $next): Response
    {
        $requestId = $request->header('X-Request-ID', (string) Str::uuid());

        $response = $next($request);

        return $response->header('X-Request-ID', $requestId);
    }
}
PHP

cat > app/Http/Middleware/ForceJsonResponse.php <<'PHP'
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ForceJsonResponse
{
    public function handle(Request $request, Closure $next): Response
    {
        $request->headers->set('Accept', 'application/json');

        return $next($request);
    }
}
PHP

echo "🧩 Middlewares créés."

# ============================================================
# 11. Génération par module (boucle sur MODULES)
# ============================================================

BINDINGS=""

for MODULE in "${MODULES[@]}"; do

    echo ""
    echo "📦 Module : $MODULE"

    mkdir -p "app/Domain/${MODULE}/Models"
    mkdir -p "app/Http/Controllers/Api/V1/${MODULE}"
    mkdir -p "app/Http/Requests/Api/V1/${MODULE}"
    mkdir -p "app/Http/Resources/Api/V1/${MODULE}"

    # --- Model + migration + factory (structure vide, à compléter) ---
    php artisan make:model "Domain/${MODULE}/Models/${MODULE}" -m -f

    # --- Controller ---
    php artisan make:controller "Api/V1/${MODULE}/${MODULE}Controller"

    # --- Form Requests ---
    php artisan make:request "Api/V1/${MODULE}/Store${MODULE}Request"
    php artisan make:request "Api/V1/${MODULE}/Update${MODULE}Request"

    # --- API Resource ---
    php artisan make:resource "Api/V1/${MODULE}/${MODULE}Resource"

    # --- Policy ---
    php artisan make:policy "${MODULE}Policy"

    # --- Repository contract ---
    cat > "app/Repositories/Contracts/${MODULE}RepositoryInterface.php" <<PHP
<?php

namespace App\Repositories\Contracts;

interface ${MODULE}RepositoryInterface extends RepositoryInterface
{
    // Ajoute ici les méthodes spécifiques à ${MODULE}
}
PHP

    # --- Repository implementation ---
    cat > "app/Repositories/Eloquent/${MODULE}Repository.php" <<PHP
<?php

namespace App\Repositories\Eloquent;

use App\Domain\${MODULE}\Models\${MODULE};
use App\Repositories\Contracts\${MODULE}RepositoryInterface;

class ${MODULE}Repository extends BaseRepository implements ${MODULE}RepositoryInterface
{
    public function __construct(${MODULE} \$model)
    {
        parent::__construct(\$model);
    }
}
PHP

    # --- Service ---
    cat > "app/Application/Services/${MODULE}Service.php" <<PHP
<?php

namespace App\Application\Services;

class ${MODULE}Service extends BaseService
{
    // Logique métier de ${MODULE} à implémenter ici
}
PHP

    # --- Actions (Create / Update / Delete) ---
    for ACTION_TYPE in Create Update Delete; do
        cat > "app/Application/Actions/${ACTION_TYPE}${MODULE}Action.php" <<PHP
<?php

namespace App\Application\Actions;

use App\Repositories\Contracts\${MODULE}RepositoryInterface;

class ${ACTION_TYPE}${MODULE}Action extends BaseAction
{
    public function __construct(private ${MODULE}RepositoryInterface \$repository)
    {
    }

    public function execute(array \$data = []): mixed
    {
        // TODO: logique métier
        return null;
    }
}
PHP
    done

    # --- DTO ---
    cat > "app/Application/DTOs/${MODULE}Data.php" <<PHP
<?php

namespace App\Application\DTOs;

final readonly class ${MODULE}Data
{
    // Ajoute ici les propriétés typées de ${MODULE}
}
PHP

    BINDINGS="${BINDINGS}        \$this->app->bind(\\App\\Repositories\\Contracts\\${MODULE}RepositoryInterface::class, \\App\\Repositories\\Eloquent\\${MODULE}Repository::class);
"

done

# ============================================================
# 12. Service Provider des repositories (bindings auto-générés)
# ============================================================

cat > app/Providers/RepositoryServiceProvider.php <<PHP
<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class RepositoryServiceProvider extends ServiceProvider
{
    public function register(): void
    {
${BINDINGS}    }

    public function boot(): void
    {
        //
    }
}
PHP

echo ""
echo "🔗 RepositoryServiceProvider généré avec les bindings de tous les modules."

# ============================================================
# 13. Tests (un test feature vide par module)
# ============================================================

for MODULE in "${MODULES[@]}"; do
    cat > "tests/Feature/${MODULE}ApiTest.php" <<PHP
<?php

namespace Tests\Feature;

use Tests\TestCase;

class ${MODULE}ApiTest extends TestCase
{
    public function test_example(): void
    {
        \$this->assertTrue(true);
    }
}
PHP
done

echo "🧪 Tests feature créés."

# ============================================================
# 14. Autoload / cache Laravel
# ============================================================

echo "🔄 Optimisation de l'autoload..."

composer dump-autoload
php artisan optimize:clear

# ============================================================
# 15. Résumé
# ============================================================

echo ""
echo "============================================================"
echo "🎉 ARCHITECTURE GÉNÉRIQUE CRÉÉE AVEC SUCCÈS"
echo "============================================================"
echo ""
echo "Modules générés : ${MODULES[*]}"
echo ""
echo "⚠️ N'oublie pas d'enregistrer le provider dans bootstrap/providers.php"
echo "   (ou config/app.php selon ta version de Laravel) :"
echo "   App\\Providers\\RepositoryServiceProvider::class"
echo ""
echo "Prochaine étape : compléter migrations, relations Eloquent,"
echo "validations et logique métier (Actions/Services)."
echo ""
echo "🚀 Architecture prête pour le développement."

