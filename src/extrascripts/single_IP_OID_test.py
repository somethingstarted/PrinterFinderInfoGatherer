import subprocess

def run_snmpget(ip, oid):
    try:
        result = subprocess.check_output(['snmpget', '-v2c', '-c', 'public', ip, oid], stderr=subprocess.STDOUT)
        return result.decode('utf-8').strip()
    except subprocess.CalledProcessError as e:
        return f"Error running snmpget: {e.output.decode('utf-8').strip()}"

def main():
    ip = input("Enter the IP: ")
    bw_oid_input = input("Enter the black/white OID(s) (comma or space separated): ").replace('"', '')
    color_oid_input = input("Enter the color OID(s) (comma or space separated): ").replace('"', '')

    bw_oids = [oid.strip() for oid in bw_oid_input.replace(',', ' ').split()]
    color_oids = [oid.strip() for oid in color_oid_input.replace(',', ' ').split()]

    print("\nBlack/White OID results:")
    for oid in bw_oids:
        print(f"{oid}: {run_snmpget(ip, oid)}")

    print("\nColor OID results:")
    for oid in color_oids:
        print(f"{oid}: {run_snmpget(ip, oid)}")

if __name__ == "__main__":
    main()
