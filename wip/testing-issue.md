# Testing Issues

<a id="top"></a>

## Table of Contents

- [Wednesday 26th August](#wednesday-26th-august)
- [Thursday 27th August](#thursday-27th-august)

<a id="wednesday-26th-august"></a>

## Wednesday 2nd September

```text
 Connect-OneView -OneViewHost va-oneviewt-01                                                                              0  16:21:19 2026-09-02 15:21:25 - Connect-OneView - INFO - Connect-OneView invoked: OneViewHost='va-oneviewt-01' DryRun=False PassThru=False Json=False
Enter OneView username for 'va-oneviewt-01': adm_98253
Enter OneView password for 'va-oneviewt-01': : ****************
2026-09-02 15:21:46 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.239.124.79
2026-09-02 15:21:47 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 25ms)
2026-09-02 15:21:51 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Available=False (DNS=True, TCP=True, Auth=False)
2026-09-02 15:21:51 - Connect-OneView - INFO - Connect-OneView result: Available=False Message='Connection to 'va-oneviewt-01' failed: Connect-OVMgmt failed: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' failed with status code '504'."'

==============================================
  OneView Connectivity Test
==============================================

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-09-02T15:21:51.2251368Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79
    TCP:       Open (port 443, 25ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    OneView PS module: HPEOneView.1000  v10.0.4265.2221 (module used for all OneView calls on this server)
    Connected: No
    Error:     Connect-OVMgmt failed: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' failed with status code '504'."
 
==============================================

   image-build-automation  feature/fix-output-tables  ping va-oneviewt-01                                                                                           0  26s 355ms  16:21:51 
Pinging va-oneviewt-01.ad.aib.pri [10.239.124.79] with 32 bytes of data:
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61
Reply from 10.239.124.79: bytes=32 time=1ms TTL=61

Ping statistics for 10.239.124.79:
    Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 1ms, Maximum = 1ms, Average = 1ms
   image-build-automation  feature/fix-output-tables  Connect-OneView -OneViewHost va-oneviewt-01                                                                    0  3s 145ms  16:22:28 2026-09-02 15:22:35 - Connect-OneView - INFO - Connect-OneView invoked: OneViewHost='va-oneviewt-01' DryRun=False PassThru=False Json=False 
Enter OneView username for 'va-oneviewt-01': adm_98253 
Enter OneView password for 'va-oneviewt-01': : **************** 
2026-09-02 15:22:58 - Connectivity - INFO - DNS resolution for 'va-oneviewt-01': Resolved -> 10.239.124.79 
2026-09-02 15:22:58 - Connectivity - INFO - TCP probe for 'va-oneviewt-01': Open (port 443, 4ms) 
2026-09-02 15:22:59 - Connectivity - INFO - Connectivity test for 'va-oneviewt-01' completed: Available=False (DNS=True, TCP=True, Auth=False) 
2026-09-02 15:22:59 - Connect-OneView - INFO - Connect-OneView result: Available=False Message='Connection to 'va-oneviewt-01' failed: Connect-OVMgmt failed: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' failed with status code '504'."'
 
==============================================
  OneView Connectivity Test
==============================================

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       va-oneviewt-01
  Environment:Prod
  Timestamp:  2026-09-02T15:22:59.8282298Z

  --- Phase 1: Network Ping ---
    DNS:       Resolved
    IP:        10.239.124.79
    TCP:       Open (port 443, 4ms)

  --- Phase 2: Auth Connect ---
    Module:    Loaded
    OneView PS module: HPEOneView.1000  v10.0.4265.2221 (module used for all OneView calls on this server)
    Connected: No 
    Error:     Connect-OVMgmt failed: The proxy tunnel request to proxy 'http://webcorp.prd.aib.pri:8082/' failed with status code '504'."

==============================================

   image-build-automation  feature/fix-output-tables  Test-ServerConnectivity                                                                                       0  24s 277ms  16:23:00 
============================================== 
  OneView Connectivity Test
============================================== 

  Status:     UNAVAILABLE
  Mode:       oneview
  Host:       
  Environment:Prod
  Timestamp:  2026-09-02T15:24:01.1329545Z     

  --- Phase 1: Network Ping --- 
    DNS:       FAILED
    TCP:       FAILED
    Error:     No active OneView connection. Connect first with Connect-OneView -OneViewHost <host> (server name or serial), or supply -OneViewHost to test a specific appliance.

  --- Phase 2: Auth Connect ---
    Module:    Not loaded
    Connected: No
    Error:     Skipped - no active connection

==============================================
```