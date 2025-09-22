-- Impede mais de uma locação aberta (endDate NULL) por veículo
CREATE UNIQUE INDEX IF NOT EXISTS "idx_unique_open_rental_per_vehicle"
  ON "Rental" ("vehicleId")
  WHERE "endDate" IS NULL;
