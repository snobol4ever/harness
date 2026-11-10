#!/usr/bin/env python3
# Generates a fully synthetic witness for FINDING-2026-08-23-seat04-json-fence0-static-release-cant-see-past-alternation-unbounded-stack-leak.md.
# Reproduces the C-stack exhaustion seen on corpus/programs/snobol4/demo/citm_catalog.json's "performances"
# section, without depending on that file's actual content. Shape matches the real file's measured branching
# (3.69 seatCategories/performance, 9.58 areas/seatCategory, averaged) closely enough that record count alone
# reproduces the crash. ⛔ THE EXACT THRESHOLD IS NOT A COMPILER-INDEPENDENT CONSTANT — it moved from
# 233-pass/234-crash to 223-pass/224-crash between two same-day rebuilds here (an unrelated activation-frame
# allocation change, SCRIP 2037a02f, shifted per-record stack cost slightly). Treat any pinned N as a snapshot,
# re-bisect with this generator before trusting a specific threshold against a new HEAD.
import sys

def make(n, n_seatcat=4, n_areas=10):
    price = '{"amount":1,"audienceSubCategoryId":2,"seatCategoryId":3}'
    area = '{"areaId":1,"blockIds":[]}'
    areas = ','.join(area for _ in range(n_areas))
    seatcat = '{"areas":[%s],"seatCategoryId":1}' % areas
    seatcats = ','.join(seatcat for _ in range(n_seatcat))
    perf = ('{"eventId":1,"id":2,"logo":null,"name":null,"prices":[%s,%s],'
            '"seatCategories":[%s],"seatMapImage":null,"start":1,"venueCode":1}') % (price, price, seatcats)
    return '[' + ','.join(perf for _ in range(n)) + ']'

if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} <record-count>")
    sys.stdout.write(make(int(sys.argv[1])))
