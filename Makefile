.PHONY: install dev test build clean

install:
    @echo "Installing dependencies..."
    cd contracts && npm install
    cd backend && go mod tidy
    cd frontend/mya-dapp && npm install

dev:
    @echo "Starting development environment..."
    docker-compose up -d

test:
    @echo "Running tests..."
    cd contracts && npm test
    cd backend && go test ./...
    cd frontend/mya-dapp && npm test

build:
    @echo "Building project..."
    cd contracts && npm run compile
    cd backend && go build ./cmd/...
    cd frontend/mya-dapp && npm run build

clean:
    @echo "Cleaning up..."
    docker-compose down
    rm -rf contracts/artifacts
    rm -rf frontend/mya-dapp/dist

