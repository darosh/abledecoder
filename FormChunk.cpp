#include "FormChunk.h"
#include "Utils.h"

FormChunk::FormChunk() : FileChunk(Utils::makeId({'F', 'O', 'R', 'M'})) {}

void FormChunk::read(std::istream &input) {
    if (Utils::readId(input) != this->id) {
        throw std::runtime_error("this does not seem to be an AIFC file");
    }

    int32_t dataSize = Utils::readInt32(input);

    this->readData(input, input.tellg(), dataSize);
}

void FormChunk::readData(std::istream &input, std::streamoff dataStart, int32_t dataSize) {
    uint32_t formType = Utils::readId(input);
    
    bool isAIFC = (formType == Utils::makeId({'A', 'I', 'F', 'C'}));
    bool isAIFF = (formType == Utils::makeId({'A', 'I', 'F', 'F'}));
    
    if (!isAIFC && !isAIFF) {
        throw std::runtime_error("form type is not AIFC or AIFF");
    }
    
    this->isAIFC = isAIFC;

    while (input.tellg() < dataStart + dataSize) {
        uint32_t subChunkId = Utils::readId(input);
        int32_t subChunkDataSize = Utils::readInt32(input);
        std::streamoff subChunkDataStart = input.tellg();
        std::streamoff subChunkDataEnd = subChunkDataStart + subChunkDataSize + (subChunkDataSize % 2 == 1 ? 1 : 0);

        // Allow for padding that might extend 1 byte beyond the file size
        if (subChunkDataSize < 0 || (subChunkDataStart + subChunkDataSize) > dataStart + dataSize) {
            throw std::runtime_error("invalid data while parsing chunks");
        }

        if (subChunkId == this->formatVersionChunk.getId()) {
            this->formatVersionChunk.readData(input, subChunkDataStart, subChunkDataSize);
        } else if (subChunkId == this->ableChunk.getId()) {
            this->ableChunk.readData(input, subChunkDataStart, subChunkDataSize);
        } else if (subChunkId == this->commonChunk.getId()) {
            this->commonChunk.readData(input, subChunkDataStart, subChunkDataSize);
        } else if (subChunkId == this->soundDataChunk.getId()) {
            this->soundDataChunk.readData(input, subChunkDataStart, subChunkDataSize);
        } else {
            // ignore unknown chunk
        }

        input.seekg(subChunkDataEnd);
    }

    if (this->commonChunk.getCompressionType() == Utils::makeId({'a', 'b', 'l', 'e'})) {
        this->soundDataChunk.decrypt(this->ableChunk.getKey());
    } else if (this->commonChunk.getCompressionType() == Utils::makeId({'N', 'O', 'N', 'E'})) {
        std::cout << "info: file was not encrypted. duplicated input file." << std::endl;
    } else {
        throw std::runtime_error("unsupported compression type. only able and NONE are supported.");
    }
}

void FormChunk::writeData(std::ostream &output) {
    // Output AIFC format for all decrypted files to ensure compatibility
    Utils::writeId(output, Utils::makeId({'A', 'I', 'F', 'C'}));
    
    this->formatVersionChunk.write(output);
    this->commonChunk.write(output);
    this->soundDataChunk.write(output);
}
