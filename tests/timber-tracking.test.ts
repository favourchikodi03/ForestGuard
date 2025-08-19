import { describe, it, expect, beforeEach } from "vitest";

interface Batch {
  owner: string;
  quantity: bigint;
  origin: string;
  harvestDate: bigint;
  certifications: string[];
  status: bigint;
}

interface HistoryEntry {
  timestamp: bigint;
  action: string;
  from?: string | null;
  to?: string | null;
}

const mockContract = {
  admin: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
  oracle: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
  paused: false,
  nextBatchId: 1n,
  batches: new Map<bigint, Batch>(),
  batchHistory: new Map<bigint, HistoryEntry[]>(),
  STATUS_PENDING: 0n,
  STATUS_VERIFIED: 1n,
  STATUS_HARVESTED: 2n,
  STATUS_INVALID: 3n,

  isAdmin(caller: string): boolean {
    return caller === this.admin;
  },

  isOracle(caller: string): boolean {
    return caller === this.oracle;
  },

  setPaused(caller: string, pause: boolean): { value: boolean } | { error: number } {
    if (!this.isAdmin(caller)) return { error: 100 };
    this.paused = pause;
    return { value: pause };
  },

  setOracle(caller: string, newOracle: string): { value: boolean } | { error: number } {
    if (!this.isAdmin(caller)) return { error: 100 };
    this.oracle = newOracle;
    return { value: true };
  },

  registerBatch(
    caller: string,
    quantity: bigint,
    origin: string,
    harvestDate: bigint,
    initialCerts: string[]
  ): { value: bigint } | { error: number } {
    if (this.paused) return { error: 104 };
    if (!this.isAdmin(caller)) return { error: 100 };
    if (quantity <= 0n) return { error: 102 };
    if (origin.length === 0) return { error: 106 };
    const batchId = this.nextBatchId;
    if (this.batches.has(batchId)) return { error: 103 };
    this.batches.set(batchId, {
      owner: caller,
      quantity,
      origin,
      harvestDate,
      certifications: initialCerts,
      status: this.STATUS_PENDING,
    });
    this.batchHistory.set(batchId, [{ timestamp: 100n, action: "registered", from: null, to: caller }]);
    this.nextBatchId += 1n;
    return { value: batchId };
  },

  transferOwnership(
    caller: string,
    batchId: bigint,
    newOwner: string
  ): { value: boolean } | { error: number } {
    if (this.paused) return { error: 104 };
    const batch = this.batches.get(batchId);
    if (!batch) return { error: 101 };
    if (batch.owner !== caller) return { error: 107 };
    if (batch.status === this.STATUS_INVALID) return { error: 110 };
    batch.owner = newOwner;
    const history = this.batchHistory.get(batchId) || [];
    history.push({ timestamp: 101n, action: "transferred", from: caller, to: newOwner });
    this.batchHistory.set(batchId, history);
    return { value: true };
  },

  splitBatch(
    caller: string,
    batchId: bigint,
    splitQuantity: bigint
  ): { value: bigint } | { error: number } {
    if (this.paused) return { error: 104 };
    const batch = this.batches.get(batchId);
    if (!batch) return { error: 101 };
    if (batch.owner !== caller) return { error: 107 };
    if (splitQuantity <= 0n || splitQuantity >= batch.quantity) return { error: 102 };
    const remaining = batch.quantity - splitQuantity;
    batch.quantity = remaining;
    const newBatchId = this.nextBatchId;
    this.batches.set(newBatchId, {
      owner: caller,
      quantity: splitQuantity,
      origin: batch.origin,
      harvestDate: batch.harvestDate,
      certifications: [...batch.certifications],
      status: batch.status,
    });
    const history = this.batchHistory.get(batchId) || [];
    history.push({ timestamp: 102n, action: "split", from: batchId.toString(), to: newBatchId.toString() });
    this.batchHistory.set(batchId, history);
    this.batchHistory.set(newBatchId, [{ timestamp: 102n, action: "created_from_split", from: batchId.toString(), to: caller }]);
    this.nextBatchId += 1n;
    return { value: newBatchId };
  },

  mergeBatches(
    caller: string,
    batchId1: bigint,
    batchId2: bigint
  ): { value: boolean } | { error: number } {
    if (this.paused) return { error: 104 };
    const batch1 = this.batches.get(batchId1);
    const batch2 = this.batches.get(batchId2);
    if (!batch1 || !batch2) return { error: 101 };
    if (batch1.owner !== caller || batch2.owner !== caller) return { error: 107 };
    if (
      batch1.origin !== batch2.origin ||
      batch1.harvestDate !== batch2.harvestDate ||
      batch1.status !== batch2.status
    ) return { error: 108 };
    batch1.quantity += batch2.quantity;
    this.batches.delete(batchId2);
    const history1 = this.batchHistory.get(batchId1) || [];
    history1.push({ timestamp: 103n, action: "merged", from: batchId2.toString(), to: null });
    this.batchHistory.set(batchId1, history1);
    return { value: true };
  },

  verifyCompliance(
    caller: string,
    batchId: bigint,
    newStatus: bigint,
    additionalCert?: string
  ): { value: boolean } | { error: number } {
    if (!this.isOracle(caller)) return { error: 109 };
    if (newStatus !== this.STATUS_VERIFIED && newStatus !== this.STATUS_INVALID) return { error: 110 };
    const batch = this.batches.get(batchId);
    if (!batch) return { error: 101 };
    batch.status = newStatus;
    if (additionalCert) batch.certifications.push(additionalCert);
    const history = this.batchHistory.get(batchId) || [];
    history.push({ timestamp: 104n, action: "verified", from: null, to: null });
    this.batchHistory.set(batchId, history);
    return { value: true };
  },
};

describe("ForestGuard Timber Tracking Contract", () => {
  beforeEach(() => {
    mockContract.admin = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";
    mockContract.oracle = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";
    mockContract.paused = false;
    mockContract.nextBatchId = 1n;
    mockContract.batches = new Map();
    mockContract.batchHistory = new Map();
  });

  it("should register a new batch when called by admin", () => {
    const result = mockContract.registerBatch(
      mockContract.admin,
      100n,
      "Forest XYZ",
      123456n,
      ["CertA"]
    );
    expect(result).toEqual({ value: 1n });
    const batch = mockContract.batches.get(1n);
    expect(batch?.quantity).toBe(100n);
    expect(batch?.status).toBe(0n);
    expect(mockContract.batchHistory.get(1n)?.length).toBe(1);
  });

  it("should prevent registration if paused", () => {
    mockContract.setPaused(mockContract.admin, true);
    const result = mockContract.registerBatch(
      mockContract.admin,
      100n,
      "Forest XYZ",
      123456n,
      ["CertA"]
    );
    expect(result).toEqual({ error: 104 });
  });

  it("should transfer ownership", () => {
    mockContract.registerBatch(
      mockContract.admin,
      100n,
      "Forest XYZ",
      123456n,
      ["CertA"]
    );
    const result = mockContract.transferOwnership(
      mockContract.admin,
      1n,
      "ST2CY5V39NHDP5P0TP2K5Q9TRFS9N4NPMHQNVQ2Q7"
    );
    expect(result).toEqual({ value: true });
    const batch = mockContract.batches.get(1n);
    expect(batch?.owner).toBe("ST2CY5V39NHDP5P0TP2K5Q9TRFS9N4NPMHQNVQ2Q7");
    expect(mockContract.batchHistory.get(1n)?.length).toBe(2);
  });

  it("should split a batch", () => {
    mockContract.registerBatch(
      mockContract.admin,
      100n,
      "Forest XYZ",
      123456n,
      ["CertA"]
    );
    const result = mockContract.splitBatch(mockContract.admin, 1n, 40n);
    expect(result).toEqual({ value: 2n });
    const original = mockContract.batches.get(1n);
    const newBatch = mockContract.batches.get(2n);
    expect(original?.quantity).toBe(60n);
    expect(newBatch?.quantity).toBe(40n);
    expect(mockContract.batchHistory.get(1n)?.length).toBe(2);
    expect(mockContract.batchHistory.get(2n)?.length).toBe(1);
  });

  it("should merge batches", () => {
    mockContract.registerBatch(
      mockContract.admin,
      100n,
      "Forest XYZ",
      123456n,
      ["CertA"]
    );
    mockContract.registerBatch(
      mockContract.admin,
      50n,
      "Forest XYZ",
      123456n,
      ["CertA"]
    );
    const result = mockContract.mergeBatches(mockContract.admin, 1n, 2n);
    expect(result).toEqual({ value: true });
    const merged = mockContract.batches.get(1n);
    expect(merged?.quantity).toBe(150n);
    expect(mockContract.batches.has(2n)).toBe(false);
    expect(mockContract.batchHistory.get(1n)?.length).toBe(2);
  });

  it("should verify compliance when called by oracle", () => {
    mockContract.registerBatch(
      mockContract.admin,
      100n,
      "Forest XYZ",
      123456n,
      ["CertA"]
    );
    const result = mockContract.verifyCompliance(
      mockContract.oracle,
      1n,
      1n,
      "NewCert"
    );
    expect(result).toEqual({ value: true });
    const batch = mockContract.batches.get(1n);
    expect(batch?.status).toBe(1n);
    expect(batch?.certifications.length).toBe(2);
    expect(mockContract.batchHistory.get(1n)?.length).toBe(2);
  });

  it("should prevent verification by non-oracle", () => {
    mockContract.registerBatch(
      mockContract.admin,
      100n,
      "Forest XYZ",
      123456n,
      ["CertA"]
    );
    const result = mockContract.verifyCompliance(
      "ST2CY5V39NHDP5P0TP2K5Q9TRFS9N4NPMHQNVQ2Q7",
      1n,
      1n
    );
    expect(result).toEqual({ error: 109 });
  });
});