public class SimplePrintResources {
    public static void main(String[] args) {
        Runtime runtime = Runtime.getRuntime();
        int processors = runtime.availableProcessors();
        long maxMemory = runtime.maxMemory();

        System.out.println("Number of processors: " + processors);
        System.out.println("Max memory: " + maxMemory + " bytes");
    }
}