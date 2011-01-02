module Net; module SSH

  class KnownHosts

    def self.remove(host)
      system "ssh-keygen -R #{host} 2>/dev/null"
    end

    def self.add_or_replace(host, key)
      host.split(",").each do |h|
        remove(h) # TODO: do this natively, without ssh-keygen
      end
      add(host, key)
    end

  end
end; end