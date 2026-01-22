/**
 * @description Service class for checking room inventory availability
 * Queries GuestroomTypeDay__c using GroupAvailable__c field
 */
public with sharing class RoomInventoryService {

    /**
     * @description Wrapper for availability check result
     */
    public class AvailabilityResult {
        public Boolean isAvailable;
        public String availabilityStatus; // full, partial, none
        public Integer requestedRooms;
        public Integer availableRooms;
        public Integer numberOfNights;
        public Decimal ratePerNight;
        public Decimal totalEstimate;
        public Date checkInDate;
        public Date checkOutDate;
        public String constrainingDate; // Date with lowest availability
        public List<DateAvailability> dateBreakdown;
        public List<RoomTypeAvailability> roomTypeBreakdown;
        public String errorMessage;

        public AvailabilityResult() {
            this.isAvailable = false;
            this.availableRooms = 0;
            this.dateBreakdown = new List<DateAvailability>();
            this.roomTypeBreakdown = new List<RoomTypeAvailability>();
        }
    }

    /**
     * @description Availability by date
     */
    public class DateAvailability {
        public Date inventoryDate;
        public Integer available;
        public Decimal rate;
        public Boolean sufficient;
    }

    /**
     * @description Availability by room type
     */
    public class RoomTypeAvailability {
        public String roomTypeName;
        public Id roomTypeId;
        public Integer minAvailable;
        public Decimal avgRate;
    }

    /**
     * @description Checks room availability for a date range at a location
     * @param locationId The Location__c record ID
     * @param checkInDate Check-in date (inclusive)
     * @param checkOutDate Check-out date (exclusive - guest doesn't stay this night)
     * @param roomsRequested Number of rooms requested
     * @param roomTypeName Optional specific room type (null or 'Any' for all types)
     * @return AvailabilityResult with availability details
     */
    public static AvailabilityResult checkAvailability(
        Id locationId,
        Date checkInDate,
        Date checkOutDate,
        Integer roomsRequested,
        String roomTypeName
    ) {
        AvailabilityResult result = new AvailabilityResult();
        result.checkInDate = checkInDate;
        result.checkOutDate = checkOutDate;
        result.requestedRooms = roomsRequested;

        // Validate inputs
        if (locationId == null) {
            result.errorMessage = 'Location ID is required';
            return result;
        }

        if (checkInDate == null || checkOutDate == null) {
            result.errorMessage = 'Check-in and check-out dates are required';
            return result;
        }

        if (checkOutDate <= checkInDate) {
            result.errorMessage = 'Check-out date must be after check-in date';
            return result;
        }

        if (roomsRequested == null || roomsRequested <= 0) {
            result.errorMessage = 'Rooms requested must be greater than 0';
            return result;
        }

        result.numberOfNights = checkInDate.daysBetween(checkOutDate);

        try {
            // Query inventory using direct Location__c lookup on GuestroomTypeDay__c
            // Using RackRate__c as per user preference
            List<GuestroomTypeDay__c> inventory = [
                SELECT Id, Name, EffectiveDate__c, GroupAvailable__c, RackRate__c,
                       Location__c, Location__r.Name,
                       GuestroomType__c, GuestroomType__r.Name,
                       GuestroomType__r.MaxOccupants__c
                FROM GuestroomTypeDay__c
                WHERE Location__c = :locationId
                AND EffectiveDate__c >= :checkInDate
                AND EffectiveDate__c < :checkOutDate
                ORDER BY EffectiveDate__c, GuestroomType__r.Name
            ];

            // Filter by room type if specified
            Boolean filterByRoomType = String.isNotBlank(roomTypeName) && roomTypeName != 'Any';

            // Aggregate availability by date
            Map<Date, Integer> availabilityByDate = new Map<Date, Integer>();
            Map<Date, Decimal> rateByDate = new Map<Date, Decimal>();
            Map<String, RoomTypeAvailability> roomTypeMap = new Map<String, RoomTypeAvailability>();

            for (GuestroomTypeDay__c inv : inventory) {
                String rtName = inv.GuestroomType__r.Name;

                // Apply room type filter if specified
                if (filterByRoomType && rtName != roomTypeName) {
                    continue;
                }

                Date invDate = inv.EffectiveDate__c;
                Integer groupAvail = inv.GroupAvailable__c != null ? Integer.valueOf(inv.GroupAvailable__c) : 0;
                Decimal rate = inv.RackRate__c != null ? inv.RackRate__c : 0;

                // Sum availability for each date (across room types if not filtered)
                Integer currentAvail = availabilityByDate.get(invDate);
                if (currentAvail == null) {
                    currentAvail = 0;
                }
                availabilityByDate.put(invDate, currentAvail + groupAvail);

                // Track rate (use first non-zero rate found per date)
                if (!rateByDate.containsKey(invDate) || rateByDate.get(invDate) == 0) {
                    rateByDate.put(invDate, rate);
                }

                // Track room type breakdown
                if (!roomTypeMap.containsKey(rtName)) {
                    RoomTypeAvailability rta = new RoomTypeAvailability();
                    rta.roomTypeName = rtName;
                    rta.roomTypeId = inv.GuestroomType__c;
                    rta.minAvailable = groupAvail;
                    rta.avgRate = rate;
                    roomTypeMap.put(rtName, rta);
                } else {
                    RoomTypeAvailability rta = roomTypeMap.get(rtName);
                    if (groupAvail < rta.minAvailable) {
                        rta.minAvailable = groupAvail;
                    }
                }
            }

            // Find minimum availability and calculate metrics
            Integer minAvailable = null;
            Date constrainingDate = null;
            Decimal totalRate = 0;
            Integer rateCount = 0;

            // Generate all dates in range and check each
            Date currentDate = checkInDate;
            while (currentDate < checkOutDate) {
                Integer avail = availabilityByDate.get(currentDate);
                if (avail == null) {
                    avail = 0; // No inventory record means no availability
                }

                DateAvailability da = new DateAvailability();
                da.inventoryDate = currentDate;
                da.available = avail;
                da.rate = rateByDate.get(currentDate);
                da.sufficient = avail >= roomsRequested;
                result.dateBreakdown.add(da);

                // Track minimum
                if (minAvailable == null || avail < minAvailable) {
                    minAvailable = avail;
                    constrainingDate = currentDate;
                }

                // Accumulate rates
                Decimal dayRate = rateByDate.get(currentDate);
                if (dayRate != null && dayRate > 0) {
                    totalRate += dayRate;
                    rateCount++;
                }

                currentDate = currentDate.addDays(1);
            }

            // Handle case where no inventory records exist
            if (minAvailable == null) {
                minAvailable = 0;
            }

            // Populate result
            result.availableRooms = minAvailable;
            result.constrainingDate = constrainingDate != null ? String.valueOf(constrainingDate) : null;
            result.ratePerNight = rateCount > 0 ? (totalRate / rateCount) : 0;

            // Determine availability status
            if (minAvailable >= roomsRequested) {
                result.isAvailable = true;
                result.availabilityStatus = 'full';
                result.totalEstimate = result.ratePerNight * result.numberOfNights * roomsRequested;
            } else if (minAvailable > 0) {
                result.isAvailable = false;
                result.availabilityStatus = 'partial';
                result.totalEstimate = result.ratePerNight * result.numberOfNights * minAvailable;
            } else {
                result.isAvailable = false;
                result.availabilityStatus = 'none';
                result.totalEstimate = 0;
            }

            // Add room type breakdown
            result.roomTypeBreakdown.addAll(roomTypeMap.values());

        } catch (Exception e) {
            result.errorMessage = 'Error checking availability: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, 'Availability check error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }

        return result;
    }

    /**
     * @description Converts availability result to JSON for prompt template
     * @param result The AvailabilityResult
     * @return JSON string representation
     */
    public static String toJson(AvailabilityResult result) {
        return JSON.serialize(result);
    }

    /**
     * @description Creates a summary string of availability
     * @param result The AvailabilityResult
     * @return Human-readable summary
     */
    public static String getSummary(AvailabilityResult result) {
        if (result == null) {
            return 'Unable to check availability';
        }

        if (String.isNotBlank(result.errorMessage)) {
            return 'Error: ' + result.errorMessage;
        }

        String summary = '';

        if (result.availabilityStatus == 'full') {
            summary = 'Full availability: ' + result.availableRooms + ' rooms available ' +
                     'for ' + result.numberOfNights + ' nights at $' +
                     result.ratePerNight.setScale(2) + '/night. ' +
                     'Estimated total: $' + result.totalEstimate.setScale(2);
        } else if (result.availabilityStatus == 'partial') {
            summary = 'Partial availability: Only ' + result.availableRooms + ' of ' +
                     result.requestedRooms + ' requested rooms available. ' +
                     'Limited availability on ' + result.constrainingDate + '.';
        } else {
            summary = 'No availability for the requested dates.';
        }

        return summary;
    }
}
