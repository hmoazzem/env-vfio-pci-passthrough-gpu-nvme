# source 
vfio() {
    local action=$1
    local pci_addr=$2
    local driver=$3

    if [[ -z $action || -z $pci_addr || -z $driver || $# -gt 3 ]]; then
        echo " source vfio.sh"
        echo "Usage: vfio bind|unbind <device> <driver>"
        echo "Example:"
        echo "  vfio bind 6e:00.0 nvme  # Bind the PCI device 6e:00.0 to the vfio-pci driver"
        echo "  vfio unbind 6e:00.0 nvme # Unbind the PCI device 6e:00.0 from vfio-pci and revert to nvme driver"
        return 1
    fi

    # Validate PCI address format
    if [[ ! "$pci_addr" =~ ^[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$ ]]; then
        echo "Invalid PCI address format. Use BB:DD.F (e.g., 6e:00.0)"
        return 1
    fi

    case $action in
        bind)
            echo "Binding device $pci_addr to vfio-pci driver"
            echo "0000:$pci_addr" | sudo tee /sys/bus/pci/drivers/$driver/unbind > /dev/null
            echo vfio-pci | sudo tee /sys/bus/pci/devices/0000:$pci_addr/driver_override > /dev/null
            echo "0000:$pci_addr" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind > /dev/null
            ;;
        unbind)
            echo "Unbinding device $pci_addr from vfio-pci and reverting to $driver driver"
            echo "0000:$pci_addr" | sudo tee /sys/bus/pci/drivers/vfio-pci/unbind > /dev/null
            echo "" | sudo tee /sys/bus/pci/devices/0000:$pci_addr/driver_override > /dev/null
            echo "0000:$pci_addr" | sudo tee /sys/bus/pci/drivers/$driver/bind > /dev/null
            ;;
        *)
            echo "Invalid action: $action. Use 'bind' or 'unbind'."
            echo " source vfio.sh"
            echo "Usage: vfio bind|unbind <device> <driver>"
            echo "Example:"
            echo "  vfio bind 6e:00.0 nvme  # Bind the PCI device 6e:00.0 to the vfio-pci driver"
            echo "  vfio unbind 6e:00.0 nvme # Unbind the PCI device 6e:00.0 from vfio-pci and revert to nvme driver"
            return 1
            ;;
    esac
}
