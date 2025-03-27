import { describe, it, expect, beforeEach, vi } from 'vitest';

// Mock the Clarity contract environment
const mockBatches = new Map();
const mockCustodyEvents = new Map();
const mockBatchEventCounters = new Map();
let mockBlockHeight = 100;
let mockBlockTime = 1625097600; // Example timestamp
let mockTxSender = 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7';
let mockAdmin = mockTxSender;

// Constants
const STATUS_PRODUCED = 'produced';
const STATUS_TRANSIT = 'transit';
const STATUS_DELIVERED = 'delivered';
const STATUS_DISPENSED = 'dispensed';
const STATUS_RECALLED = 'recalled';

const EVENT_PRODUCTION = 'production';
const EVENT_TRANSFER = 'transfer';
const EVENT_DELIVERY = 'delivery';
const EVENT_DISPENSING = 'dispensing';
const EVENT_RECALL = 'recall';

// Mock contract functions
const batchTrackingContract = {
  // Data variables
  admin: mockAdmin,
  
  // Maps
  batches: mockBatches,
  'custody-events': mockCustodyEvents,
  'batch-event-counters': mockBatchEventCounters,
  
  // Helper functions to simulate Clarity behavior
  'get-block-info?': (key, height) => {
    if (key === 'time') {
      return { type: 'some', value: mockBlockTime };
    }
    return { type: 'none' };
  },
  
  // Contract functions
  'register-batch': (batchId, manufacturerId, medicationName, dosage, form, quantity, productionDate, expiryDate) => {
    const batchKey = JSON.stringify({ 'batch-id': batchId });
    
    if (mockBatches.has(batchKey)) {
      return { type: 'err', value: 1001 };
    }
    
    if (expiryDate <= productionDate) {
      return { type: 'err', value: 1004 };
    }
    
    mockBatches.set(batchKey, {
      'manufacturer-id': manufacturerId,
      'medication-name': medicationName,
      dosage,
      form,
      quantity,
      'production-date': productionDate,
      'expiry-date': expiryDate,
      'current-custodian': mockTxSender,
      status: STATUS_PRODUCED
    });
    
    // Initialize event counter
    mockBatchEventCounters.set(batchKey, { counter: 0 });
    
    // Record production event
    const eventKey = JSON.stringify({ 'batch-id': batchId, 'event-id': 0 });
    mockCustodyEvents.set(eventKey, {
      from: mockTxSender,
      to: mockTxSender,
      timestamp: mockBlockTime,
      location: 'Production Facility',
      'event-type': EVENT_PRODUCTION,
      notes: 'Batch produced'
    });
    
    // Increment counter
    mockBatchEventCounters.set(batchKey, { counter: 1 });
    
    return { type: 'ok', value: true };
  },
  
  'transfer-batch': (batchId, to, location, notes) => {
    const batchKey = JSON.stringify({ 'batch-id': batchId });
    
    if (!mockBatches.has(batchKey)) {
      return { type: 'err', value: 1002 };
    }
    
    const batchData = mockBatches.get(batchKey);
    
    if (batchData['current-custodian'] !== mockTxSender) {
      return { type: 'err', value: 1003 };
    }
    
    if (batchData.status === STATUS_RECALLED) {
      return { type: 'err', value: 1005 };
    }
    
    // Update batch
    batchData['current-custodian'] = to;
    batchData.status = STATUS_TRANSIT;
    mockBatches.set(batchKey, batchData);
    
    // Record transfer event
    const counterData = mockBatchEventCounters.get(batchKey);
    const eventId = counterData.counter;
    const eventKey = JSON.stringify({ 'batch-id': batchId, 'event-id': eventId });
    
    mockCustodyEvents.set(eventKey, {
      from: mockTxSender,
      to,
      timestamp: mockBlockTime,
      location,
      'event-type': EVENT_TRANSFER,
      notes
    });
    
    // Increment counter
    mockBatchEventCounters.set(batchKey, { counter: eventId + 1 });
    
    return { type: 'ok', value: true };
  },
  
  'deliver-batch': (batchId, location, notes) => {
    const batchKey = JSON.stringify({ 'batch-id': batchId });
    
    if (!mockBatches.has(batchKey)) {
      return { type: 'err', value: 1002 };
    }
    
    const batchData = mockBatches.get(batchKey);
    
    if (batchData['current-custodian'] !== mockTxSender) {
      return { type: 'err', value: 1003 };
    }
    
    if (batchData.status === STATUS_RECALLED) {
      return { type: 'err', value: 1005 };
    }
    
    // Update batch
    batchData.status = STATUS_DELIVERED;
    mockBatches.set(batchKey, batchData);
    
    // Record delivery event
    const counterData = mockBatchEventCounters.get(batchKey);
    const eventId = counterData.counter;
    const eventKey = JSON.stringify({ 'batch-id': batchId, 'event-id': eventId });
    
    mockCustodyEvents.set(eventKey, {
      from: mockTxSender,
      to: mockTxSender,
      timestamp: mockBlockTime,
      location,
      'event-type': EVENT_DELIVERY,
      notes
    });
    
    // Increment counter
    mockBatchEventCounters.set(batchKey, { counter: eventId + 1 });
    
    return { type: 'ok', value: true };
  },
  
  'get-batch': (batchId) => {
    const batchKey = JSON.stringify({ 'batch-id': batchId });
    
    if (!mockBatches.has(batchKey)) {
      return { type: 'none' };
    }
    
    return { type: 'some', value: mockBatches.get(batchKey) };
  },
  
  'get-custody-event': (batchId, eventId) => {
    const eventKey = JSON.stringify({ 'batch-id': batchId, 'event-id': eventId });
    
    if (!mockCustodyEvents.has(eventKey)) {
      return { type: 'none' };
    }
    
    return { type: 'some', value: mockCustodyEvents.get(eventKey) };
  },
  
  'get-event-count': (batchId) => {
    const batchKey = JSON.stringify({ 'batch-id': batchId });
    
    if (!mockBatchEventCounters.has(batchKey)) {
      return 0;
    }
    
    return mockBatchEventCounters.get(batchKey).counter;
  }
};

// Tests
describe('Batch Tracking Contract', () => {
  beforeEach(() => {
    // Reset state before each test
    mockBatches.clear();
    mockCustodyEvents.clear();
    mockBatchEventCounters.clear();
    mockBlockTime = 1625097600;
    mockTxSender = 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7';
  });
  
  describe('register-batch', () => {
    it('should register a new batch successfully', () => {
      const batchId = 'BATCH-123456';
      const manufacturerId = '123e4567-e89b-12d3-a456-426614174000';
      const medicationName = 'Ibuprofen';
      const dosage = '200mg';
      const form = 'Tablet';
      const quantity = 1000;
      const productionDate = mockBlockTime - 86400; // 1 day ago
      const expiryDate = mockBlockTime + 31536000; // 1 year later
      
      const result = batchTrackingContract['register-batch'](
          batchId, manufacturerId, medicationName, dosage, form, quantity, productionDate, expiryDate
      );
      
      expect(result.type).toBe('ok');
      
      const batchData = batchTrackingContract['get-batch'](batchId);
      expect(batchData.type).toBe('some');
      expect(batchData.value['medication-name']).toBe(medicationName);
      expect(batchData.value.status).toBe(STATUS_PRODUCED);
      
      // Check production event was recorded
      const eventCount = batchTrackingContract['get-event-count'](batchId);
      expect(eventCount).toBe(1);
      
      const eventData = batchTrackingContract['get-custody-event'](batchId, 0);
      expect(eventData.type).toBe('some');
      expect(eventData.value['event-type']).toBe(EVENT_PRODUCTION);
    });
    
    it('should fail when registering a batch with expiry date before production date', () => {
      const batchId = 'BATCH-123456';
      const manufacturerId = '123e4567-e89b-12d3-a456-426614174000';
      const medicationName = 'Ibuprofen';
      const dosage = '200mg';
      const form = 'Tablet';
      const quantity = 1000;
      const productionDate = mockBlockTime;
      const expiryDate = mockBlockTime - 86400; // 1 day before production (invalid)
      
      const result = batchTrackingContract['register-batch'](
          batchId, manufacturerId, medicationName, dosage, form, quantity, productionDate, expiryDate
      );
      
      expect(result.type).toBe('err');
      expect(result.value).toBe(1004);
    });
  });
  
  describe('transfer-batch', () => {
    it('should transfer a batch successfully', () => {
      // First register a batch
      const batchId = 'BATCH-123456';
      const manufacturerId = '123e4567-e89b-12d3-a456-426614174000';
      const medicationName = 'Ibuprofen';
      const dosage = '200mg';
      const form = 'Tablet';
      const quantity = 1000;
      const productionDate = mockBlockTime - 86400;
      const expiryDate = mockBlockTime + 31536000;
      
      batchTrackingContract['register-batch'](
          batchId, manufacturerId, medicationName, dosage, form, quantity, productionDate, expiryDate
      );
      
      // Now transfer the batch
      const to = 'SP3FGQ8Z7JY9BWYZ5WM53E0M9NK7WHJF0691NZ159';
      const location = 'Distribution Center';
      const notes = 'Transferred to distributor';
      
      const result = batchTrackingContract['transfer-batch'](batchId, to, location, notes);
      
      expect(result.type).toBe('ok');
      
      const batchData = batchTrackingContract['get-batch'](batchId);
      expect(batchData.value['current-custodian']).toBe(to);
      expect(batchData.value.status).toBe(STATUS_TRANSIT);
      
      // Check transfer event was recorded
      const eventCount = batchTrackingContract['get-event-count'](batchId);
      expect(eventCount).toBe(2);
      
      const eventData = batchTrackingContract['get-custody-event'](batchId, 1);
      expect(eventData.value['event-type']).toBe(EVENT_TRANSFER);
      expect(eventData.value.from).toBe(mockTxSender);
      expect(eventData.value.to).toBe(to);
    });
    
    it('should fail when non-custodian tries to transfer a batch', () => {
      // First register a batch
      const batchId = 'BATCH-123456';
      const manufacturerId = '123e4567-e89b-12d3-a456-426614174000';
      const medicationName = 'Ibuprofen';
      const dosage = '200mg';
      const form = 'Tablet';
      const quantity = 1000;
      const productionDate = mockBlockTime - 86400;
      const expiryDate = mockBlockTime + 31536000;
      
      batchTrackingContract['register-batch'](
          batchId, manufacturerId, medicationName, dosage, form, quantity, productionDate, expiryDate
      );
      
      // Change tx-sender to non-custodian
      const originalSender = mockTxSender;
      mockTxSender = 'SP3FGQ8Z7JY9BWYZ5WM53E0M9NK7WHJF0691NZ159';
      
      // Try to transfer the batch
      const to = 'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE';
      const location = 'Distribution Center';
      const notes = 'Transferred to distributor';
      
      const result = batchTrackingContract['transfer-batch'](batchId, to, location, notes);
      
      expect(result.type).toBe('err');
      expect(result.value).toBe(1003);
      
      // Restore tx-sender
      mockTxSender = originalSender;
    });
  });
});
